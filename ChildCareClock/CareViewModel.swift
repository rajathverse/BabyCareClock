import SwiftUI
import UIKit
import WidgetKit

/// A short message above the tab bar, optionally offering Undo.
struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let symbol: String
    let canUndo: Bool
}

/// Connects UI actions to the scheduling engine, local storage (plus the Keychain copy),
/// notifications, the widget and the Watch. Shared so notification actions can reach it in the background.
@MainActor
final class CareViewModel: ObservableObject {
    static let shared = CareViewModel()

    @Published private(set) var state: CareState
    @Published private(set) var photo: UIImage?
    @Published var toast: Toast?
    /// Data found in the Keychain after a reinstall, offered on the welcome screen.
    @Published private(set) var restorableBackup: CareState?

    private var undoSnapshot: CareState?
    private var toastTask: Task<Void, Never>?

    private init() {
        state = CarePersistence.load() ?? CareState()
        photo = PhotoStore.load()
        if state.isSetUp {
            KeychainBackup.saveState(state)
            KeychainBackup.savePhoto(try? Data(contentsOf: PhotoStore.url))
        } else {
            restorableBackup = KeychainBackup.loadState()
        }
        CareSync.observe { [weak self] in self?.reloadFromDisk() }
        LiveActivityManager.endAll()
    }

    /// Picks up changes saved by the widget, Siri or the Watch.
    func reloadFromDisk() {
        guard let saved = CarePersistence.load(), saved != state else { return }
        undoSnapshot = nil
        withAnimation(.snappy) { state = saved }
        KeychainBackup.saveState(saved)
        WatchSync.shared.send(state)
    }

    var baby: BabyProfile? { state.baby }

    // MARK: Setup

    /// `doneAt` holds items the parent said were already done, e.g. a feed an hour ago.
    func completeOnboarding(baby: BabyProfile, photo: UIImage?, items: [CareItem], doneAt: [UUID: Date] = [:]) {
        var newState = CareState(baby: baby)
        for item in items {
            try? newState.addItem(item)
            if let date = doneAt[item.id] { newState.complete(item.id, at: date) }
        }
        setPhoto(photo)
        apply(newState, undoable: false)
    }

    /// Brings back the data kept in the Keychain from before the app was deleted.
    func restoreBackup() {
        guard let backup = restorableBackup else { return }
        restorableBackup = nil
        if let jpeg = KeychainBackup.loadPhoto(), let image = UIImage(data: jpeg) {
            photo = PhotoStore.save(image)
        }
        apply(backup, undoable: false)
        // Notification permission doesn't survive a reinstall, so ask again.
        Task {
            _ = await NotificationScheduler.requestAuthorization()
            refreshOutsideApp()
        }
        let message = backup.baby.map { String(appLocalized: "Welcome back! \($0.name)'s data is restored") } ?? String(appLocalized: "Welcome back! Your data is restored")
        showToast(message, symbol: "arrow.counterclockwise.circle.fill", canUndo: false)
    }

    func discardBackup() {
        restorableBackup = nil
        KeychainBackup.deleteAll()
    }

    func updateBaby(_ baby: BabyProfile) {
        var newState = state
        let birthChanged = newState.baby?.birthDate != baby.birthDate
        newState.baby = baby
        if birthChanged, let birth = baby.birthDate { newState.recalculateVaccineDates(birthDate: birth) }
        apply(newState, undoable: false)
    }

    // MARK: Vaccinations

    func startVaccines(_ schedule: VaccineSchedule?, birthDate: Date, markPastAsGiven: Bool) {
        var newState = state
        if newState.baby?.birthDate == nil { newState.baby?.birthDate = birthDate }
        if let schedule {
            newState.startVaccineSchedule(schedule, birthDate: birthDate, markPastAsGiven: markPastAsGiven)
        } else {
            newState.vaccines = []
        }
        apply(newState, undoable: false)
    }

    func setVaccineGiven(_ id: UUID, on date: Date?) {
        var newState = state
        newState.setVaccineGiven(id, on: date)
        apply(newState, undoable: true)
        if date != nil {
            SoundManager.shared.done()
            showToast(String(appLocalized: "Marked as given"), symbol: "checkmark.seal.fill", canUndo: true)
        }
    }

    func setVisitGiven(_ visit: VaccineVisit, on date: Date) {
        var newState = state
        newState.setVisitGiven(visit, on: date)
        apply(newState, undoable: true)
        SoundManager.shared.done()
        showToast(String(appLocalized: "\(visit.displayTitle) vaccines done"), symbol: "checkmark.seal.fill", canUndo: true)
    }

    func updateVaccine(_ dose: VaccineDose) {
        var newState = state
        newState.updateVaccine(dose)
        apply(newState, undoable: false)
    }

    func addVaccine(name: String, dueDate: Date) {
        var newState = state
        newState.addVaccine(name: name, dueDate: dueDate)
        apply(newState, undoable: false)
    }

    /// Vaccines read from a photo of the card and checked by the parent.
    func addScannedVaccines(_ scanned: [ScannedVaccine], birthDate: Date) {
        var newState = state
        if newState.baby?.birthDate == nil { newState.baby?.birthDate = birthDate }
        for vaccine in scanned {
            let name = vaccine.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            newState.vaccines.append(VaccineDose(name: name, visit: "Added by you", dueDate: vaccine.date, givenDate: vaccine.isGiven ? vaccine.date : nil, dueDateEdited: true))
        }
        apply(newState, undoable: false)
    }

    func deleteVaccine(_ id: UUID) {
        var newState = state
        newState.deleteVaccine(id)
        apply(newState, undoable: true)
        showToast(String(appLocalized: "Vaccine removed"), symbol: "trash", canUndo: true)
    }

    func setPhoto(_ image: UIImage?) {
        if let image {
            photo = PhotoStore.save(image)
        } else {
            PhotoStore.delete()
            photo = nil
        }
        KeychainBackup.savePhoto(try? Data(contentsOf: PhotoStore.url))
        refreshOutsideApp()
    }

    /// Wipes everything and returns to onboarding.
    func resetAll() {
        PhotoStore.delete()
        CarePersistence.delete()
        NotificationScheduler.clearAll()
        KeychainBackup.deleteAll()
        restorableBackup = nil
        photo = nil
        undoSnapshot = nil
        toast = nil
        state = CareState()
        refreshOutsideApp()
    }

    // MARK: Care plan

    func addItem(_ item: CareItem, alreadyDoneAt doneDate: Date?) throws {
        var newState = state
        try newState.addItem(item)
        if let doneDate { newState.complete(item.id, at: doneDate) }
        apply(newState, undoable: false)
        showToast(String(appLocalized: "\(item.name) added"), symbol: item.symbol, canUndo: false)
    }

    func updateItem(_ item: CareItem) throws {
        var newState = state
        try newState.updateItem(item)
        apply(newState, undoable: false)
    }

    func deleteItem(_ id: UUID) {
        guard let item = state.item(id) else { return }
        var newState = state
        newState.deleteItem(id)
        NotificationScheduler.clearDelivered(for: id)
        apply(newState, undoable: true)
        showToast(String(appLocalized: "\(item.name) removed"), symbol: "trash", canUndo: true)
    }

    // MARK: Logging

    func complete(_ itemID: UUID, at date: Date = Date(), note: String = "") {
        guard let item = state.item(itemID) else { return }
        var newState = state
        newState.complete(itemID, at: date, note: note)
        NotificationScheduler.clearDelivered(for: itemID)
        apply(newState, undoable: true)
        SoundManager.shared.done()
        let minutesAgo = Int(Date().timeIntervalSince(date) / 60)
        let message = minutesAgo < 1
            ? String(appLocalized: "\(item.name) done")
            : String(appLocalized: "\(item.name) done · \(CareFormat.duration(TimeInterval(minutesAgo * 60))) ago")
        showToast(message, symbol: "checkmark.circle.fill", canUndo: true)
    }

    func snooze(_ itemID: UUID, minutes: Int = NotificationScheduler.snoozeMinutes) {
        guard let item = state.item(itemID) else { return }
        var newState = state
        newState.snooze(itemID, minutes: minutes)
        NotificationScheduler.clearDelivered(for: itemID)
        apply(newState, undoable: true)
        SoundManager.shared.snooze()
        showToast(String(appLocalized: "\(item.name) snoozed \(minutes) min"), symbol: "clock.arrow.circlepath", canUndo: true)
    }

    func skip(_ itemID: UUID) {
        guard let item = state.item(itemID) else { return }
        var newState = state
        newState.skip(itemID)
        NotificationScheduler.clearDelivered(for: itemID)
        apply(newState, undoable: true)
        SoundManager.shared.selection()
        showToast(String(appLocalized: "\(item.name) skipped"), symbol: "forward.end.fill", canUndo: true)
    }

    func deleteEvent(_ id: UUID) {
        var newState = state
        newState.deleteEvent(id)
        apply(newState, undoable: true)
        showToast(String(appLocalized: "Entry deleted"), symbol: "trash", canUndo: true)
    }

    func updateEvent(_ id: UUID, date: Date, note: String) {
        var newState = state
        newState.updateEvent(id, date: date, note: note)
        apply(newState, undoable: false)
    }

    func undo() {
        guard let snapshot = undoSnapshot else { return }
        undoSnapshot = nil
        toast = nil
        apply(snapshot, undoable: false)
        SoundManager.shared.selection()
    }

    // MARK: Plumbing

    /// Re-syncs notifications, the widget and the Watch, e.g. after a settings change.
    func refreshOutsideApp() {
        NotificationScheduler.reschedule(state: state)
        WidgetCenter.shared.reloadAllTimelines()
        WatchSync.shared.send(state)
        CareShortcuts.updateAppShortcutParameters()
    }

    func saveNow() {
        CarePersistence.save(state)
    }

    private func apply(_ newState: CareState, undoable: Bool) {
        undoSnapshot = undoable ? state : nil
        withAnimation(.snappy) { state = newState }
        CarePersistence.save(newState)
        KeychainBackup.saveState(newState)
        refreshOutsideApp()
    }

    private func showToast(_ message: String, symbol: String, canUndo: Bool) {
        toastTask?.cancel()
        let toast = Toast(message: message, symbol: symbol, canUndo: canUndo)
        withAnimation(.spring(duration: 0.35)) { self.toast = toast }
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, let self, self.toast?.id == toast.id else { return }
            withAnimation(.easeOut(duration: 0.25)) { self.toast = nil }
            if canUndo { self.undoSnapshot = nil }
        }
    }

    func dismissToast() {
        toastTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) { toast = nil }
    }
}
