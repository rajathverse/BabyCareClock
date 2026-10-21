import AppIntents
import SwiftUI
import WidgetKit

struct NextUpEntry: TimelineEntry {
    let date: Date
    let babyName: String
    let upcoming: [ScheduledItem]
    let photo: UIImage?
    let isSetUp: Bool
}

struct NextUpProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextUpEntry {
        let now = Date()
        let sample = [
            ScheduledItem(item: CareItem(kind: .care, name: "Feed", symbol: "drop.fill", intervalMinutes: 180, firstDue: now), due: now.addingTimeInterval(70 * 60)),
            ScheduledItem(item: CareItem(kind: .medicine, name: "Vitamin D3", symbol: "sun.max.fill", intervalMinutes: 1440, firstDue: now), due: now.addingTimeInterval(4 * 3600)),
        ]
        return NextUpEntry(date: now, babyName: "Baby", upcoming: sample, photo: nil, isSetUp: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (NextUpEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextUpEntry>) -> Void) {
        let now = Date()
        let state = CarePersistence.load() ?? CareState()
        let schedule = CareEngine.schedule(for: state)
        // Refresh when each of the next few items becomes due, so "Due now" appears on time.
        var dates = [now]
        dates += schedule.prefix(4).map(\.due).filter { $0 > now }
        let entries = dates.sorted().map { entry(at: $0, state: state) }
        let refresh = now.addingTimeInterval(30 * 60)
        completion(Timeline(entries: entries, policy: .after(min(refresh, dates.last ?? refresh))))
    }

    private func entry(at date: Date, state: CareState? = nil) -> NextUpEntry {
        let state = state ?? CarePersistence.load() ?? CareState()
        return NextUpEntry(
            date: date,
            babyName: state.baby?.name ?? "",
            upcoming: Array(CareEngine.schedule(for: state).prefix(3)),
            photo: PhotoStore.load(),
            isSetUp: state.isSetUp
        )
    }
}

struct NextUpWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextUpWidget", provider: NextUpProvider()) { entry in
            NextUpWidgetView(entry: entry)
        }
        .configurationDisplayName("Next up")
        .description("Your baby's photo and what's due next.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct NextUpWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NextUpEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular: circular
            case .accessoryRectangular: rectangular
            case .accessoryInline: inline
            case .systemMedium: medium
            default: small
            }
        }
        .fontDesign(.rounded)
        .containerBackground(for: .widget) { background }
    }

    private var next: ScheduledItem? { entry.upcoming.first }

    @ViewBuilder
    private var background: some View {
        switch family {
        case .systemSmall:
            if let photo = entry.photo {
                Image(uiImage: photo).resizable().scaledToFill()
            } else {
                AppBackground()
            }
        case .systemMedium:
            AppBackground()
        default:
            Color.clear
        }
    }

    // MARK: Home Screen

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            if let next {
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 1) {
                        Label(next.item.name, systemImage: next.item.symbol)
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                        countdown(next)
                            .font(.headline.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    doneButton(next.item, compact: false)
                }
                .foregroundStyle(entry.photo == nil ? AppPalette.text : .white)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    if entry.photo != nil {
                        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.ultraThinMaterial.opacity(0.9))
                            .environment(\.colorScheme, .dark)
                    }
                }
            } else {
                emptyText
            }
        }
    }

    private var medium: some View {
        HStack(spacing: 14) {
            if let photo = entry.photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 112)
                    .frame(maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.babyName.isEmpty ? "Next up" : entry.babyName)
                    .font(.headline)
                    .foregroundStyle(AppPalette.text)
                if entry.upcoming.isEmpty {
                    emptyText
                }
                ForEach(entry.upcoming) { scheduled in
                    HStack(spacing: 8) {
                        SymbolBadge(symbol: scheduled.item.symbol, kind: scheduled.item.kind, size: 26)
                        Text(scheduled.item.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppPalette.text)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        countdown(scheduled)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(scheduled.due <= entry.date ? AppPalette.overdueText : AppPalette.primaryDeep)
                            .lineLimit(1)
                        doneButton(scheduled.item, compact: true)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Lock Screen

    @ViewBuilder
    private var circular: some View {
        if let next, next.due > entry.date {
            ProgressView(timerInterval: CareEngine.cycleStart(for: next.item, due: next.due)...next.due, countsDown: true) {
                Image(systemName: next.item.symbol)
            } currentValueLabel: {
                Image(systemName: next.item.symbol)
            }
            .progressViewStyle(.circular)
        } else if let next {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: next.item.symbol).font(.title3)
            }
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "checkmark")
            }
        }
    }

    @ViewBuilder
    private var rectangular: some View {
        if let next {
            VStack(alignment: .leading, spacing: 1) {
                Label(next.item.name, systemImage: next.item.symbol)
                    .font(.headline)
                    .lineLimit(1)
                countdown(next)
                    .font(.title3.weight(.semibold))
                Text("at \(next.due.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            emptyText
        }
    }

    @ViewBuilder
    private var inline: some View {
        if let next {
            Label("\(next.item.name) · \(next.due.formatted(date: .omitted, time: .shortened))", systemImage: next.item.symbol)
        } else {
            Text("All caught up")
        }
    }

    // MARK: Pieces

    /// Logs the item straight from the widget (iOS 17 interactive widgets).
    private func doneButton(_ item: CareItem, compact: Bool) -> some View {
        Button(intent: LogCareItemIntent(item: CareItemEntity(item: item))) {
            if compact {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppPalette.onPrimary)
                    .frame(width: 26, height: 26)
                    .background(AppPalette.primary, in: Circle())
            } else {
                Label("Done", systemImage: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppPalette.onPrimary)
                    .frame(maxWidth: .infinity, minHeight: 28)
                    .background(AppPalette.primary, in: Capsule())
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mark \(item.name) done")
    }

    @ViewBuilder
    private func countdown(_ scheduled: ScheduledItem) -> some View {
        if scheduled.due > entry.date {
            Text(timerInterval: entry.date...scheduled.due, countsDown: true)
                .monospacedDigit()
        } else {
            Text("Due now")
        }
    }

    private var emptyText: some View {
        Text(entry.isSetUp ? "All caught up" : "Open Baby Care Clock to get started")
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppPalette.secondaryText)
    }
}
