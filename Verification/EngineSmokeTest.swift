import Foundation

// Plain-Swift checks for the scheduling engine. Run with ./verify_engine.sh.

var failures = 0
var checks = 0

func expect(_ condition: @autoclosure () -> Bool, _ message: String, line: Int = #line) {
    checks += 1
    if !condition() {
        failures += 1
        print("FAIL (line \(line)): \(message)")
    }
}

let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    return calendar
}()

func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

let hour: TimeInterval = 3600

@main
enum EngineSmokeTest {
    static func main() {
        // MARK: Next due without any log uses the first due time
        do {
            let now = date(2026, 10, 17, 9)
            var state = CareState(baby: BabyProfile(name: "Baby"))
            let feed = CareItem(kind: .care, name: "Feed", symbol: "drop.fill", intervalMinutes: 180, firstDue: now)
            try! state.addItem(feed)
            expect(CareEngine.nextDue(for: state.items[0], in: state) == now, "no log: due at first due")

            // Future first due
            let vitamin = CareItem(kind: .medicine, name: "Vitamin D3", symbol: "sun.max.fill", intervalMinutes: 1440, firstDue: date(2026, 10, 17, 21))
            try! state.addItem(vitamin)
            expect(CareEngine.nextDue(for: state.items[1], in: state) == date(2026, 10, 17, 21), "future first due kept")
            expect(CareEngine.schedule(for: state).map(\.item.name) == ["Feed", "Vitamin D3"], "schedule sorted by due")
        }

        // MARK: Completion, backdating and the latest log wins
        do {
            let now = date(2026, 10, 17, 12)
            var state = CareState()
            let item = CareItem(kind: .care, name: "Feed", symbol: "drop.fill", intervalMinutes: 180, firstDue: now)
            try! state.addItem(item)
            state.complete(item.id, at: now.addingTimeInterval(-30 * 60), now: now)
            expect(CareEngine.nextDue(for: state.items[0], in: state) == date(2026, 10, 17, 14, 30), "backdated 30 min: due 2:30 PM")

            // Logging an older dose does not move the schedule back
            state.complete(item.id, at: date(2026, 10, 17, 8), now: now)
            expect(CareEngine.nextDue(for: state.items[0], in: state) == date(2026, 10, 17, 14, 30), "older log doesn't override latest")

            // Future completion is clamped to now
            let future = state.complete(item.id, at: now.addingTimeInterval(hour), now: now)
            expect(future?.date == now, "future completion clamped to now")
            expect(CareEngine.nextDue(for: state.items[0], in: state) == date(2026, 10, 17, 15), "due 3h after now")

            // Deleting the latest event recalculates from the previous one
            state.deleteEvent(future!.id)
            expect(CareEngine.nextDue(for: state.items[0], in: state) == date(2026, 10, 17, 14, 30), "delete recalculates")

            // Editing an event's time recalculates too
            let latest = CareEngine.latestEvent(for: item.id, in: state)!
            state.updateEvent(latest.id, date: date(2026, 10, 17, 11), note: " Left side ", now: now)
            expect(CareEngine.nextDue(for: state.items[0], in: state) == date(2026, 10, 17, 14), "edit recalculates")
            expect(state.events.first { $0.id == latest.id }?.note == "Left side", "note trimmed")

            // Changing the interval recalculates from the last log
            var edited = state.items[0]
            edited.intervalMinutes = 120
            try! state.updateItem(edited)
            expect(CareEngine.nextDue(for: state.items[0], in: state) == date(2026, 10, 17, 13), "interval change recalculates")
        }

        // MARK: Snooze and skip
        do {
            let now = date(2026, 10, 17, 10)
            var state = CareState()
            let item = CareItem(kind: .care, name: "Diaper", symbol: "sparkles", intervalMinutes: 180, firstDue: date(2026, 10, 17, 9))
            try! state.addItem(item)

            // Overdue snooze counts from now
            state.snooze(item.id, minutes: 15, now: now)
            expect(CareEngine.nextDue(for: state.items[0], in: state) == date(2026, 10, 17, 10, 15), "snooze overdue from now")
            // Snoozing again stacks
            state.snooze(item.id, minutes: 15, now: now)
            expect(CareEngine.nextDue(for: state.items[0], in: state) == date(2026, 10, 17, 10, 30), "snooze stacks")
            // Completing clears the snooze
            state.complete(item.id, at: now, now: now)
            expect(state.items[0].snoozedUntil == nil, "complete clears snooze")
            expect(CareEngine.nextDue(for: state.items[0], in: state) == date(2026, 10, 17, 13), "after complete due +3h")

            // Skip an upcoming dose keeps the rhythm
            state.skip(item.id, now: now)
            expect(CareEngine.nextDue(for: state.items[0], in: state) == date(2026, 10, 17, 16), "skip upcoming: next slot")

            // Completing after a future skip removes the skip
            state.complete(item.id, at: date(2026, 10, 17, 10, 5), now: date(2026, 10, 17, 10, 5))
            expect(!state.events.contains { $0.kind == .skipped }, "future skip removed by later completion")
            expect(CareEngine.nextDue(for: state.items[0], in: state) == date(2026, 10, 17, 13, 5), "due from completion")

            // Skipping a very overdue dose jumps to the first slot after now
            var overdueState = CareState()
            let med = CareItem(kind: .medicine, name: "Iron", symbol: "eyedropper.halffull", intervalMinutes: 180, firstDue: date(2026, 10, 17, 1))
            try! overdueState.addItem(med)
            overdueState.skip(med.id, now: date(2026, 10, 17, 8))
            expect(CareEngine.nextDue(for: overdueState.items[0], in: overdueState) == date(2026, 10, 17, 10), "skip overdue: first slot after now")
        }

        // MARK: Status thresholds and countdown fraction
        do {
            let now = date(2026, 10, 17, 12)
            expect(CareEngine.status(due: now.addingTimeInterval(-1), now: now, warningMinutes: 15) == .overdue, "past = overdue")
            expect(CareEngine.status(due: now, now: now, warningMinutes: 15) == .overdue, "exactly now = overdue")
            expect(CareEngine.status(due: now.addingTimeInterval(15 * 60), now: now, warningMinutes: 15) == .dueSoon, "15 min = due soon")
            expect(CareEngine.status(due: now.addingTimeInterval(16 * 60), now: now, warningMinutes: 15) == .upcoming, "16 min = upcoming")
            let item = CareItem(kind: .care, name: "Feed", symbol: "drop.fill", intervalMinutes: 180, firstDue: now)
            expect(abs(CareEngine.remainingFraction(for: item, due: now.addingTimeInterval(90 * 60), now: now) - 0.5) < 0.0001, "half way")
            expect(CareEngine.remainingFraction(for: item, due: now.addingTimeInterval(-hour), now: now) == 0, "overdue fraction 0")
        }

        // MARK: Interval math across DST (absolute elapsed time)
        do {
            // US DST ends 2026-11-01 at 2:00 AM.
            let before = date(2026, 10, 31, 23)
            var state = CareState()
            let item = CareItem(kind: .care, name: "Feed", symbol: "drop.fill", intervalMinutes: 180, firstDue: before)
            try! state.addItem(item)
            state.complete(item.id, at: before, now: before)
            let due = CareEngine.nextDue(for: state.items[0], in: state)
            expect(due.timeIntervalSince(before) == 3 * hour, "3 real hours across DST")
            expect(calendar.component(.hour, from: due) == 1, "wall clock 1 AM after fall back")
        }

        // MARK: Timeline
        do {
            let now = date(2026, 10, 17, 12)
            var state = CareState()
            let feed = CareItem(kind: .care, name: "Feed", symbol: "drop.fill", intervalMinutes: 180, firstDue: now)
            let bath = CareItem(kind: .care, name: "Bath", symbol: "bathtub.fill", intervalMinutes: 1440, firstDue: date(2026, 10, 17, 9))
            try! state.addItem(feed)
            try! state.addItem(bath)
            state.complete(feed.id, at: date(2026, 10, 17, 11), note: "Left", now: now)
            state.complete(feed.id, at: date(2026, 10, 16, 22), now: now)

            let today = CareEngine.timeline(for: now, in: state, now: now, calendar: calendar)
            let done = today.filter { $0.kind == .done }
            expect(done.count == 1 && done[0].note == "Left", "today shows today's log only")
            expect(today.contains { $0.kind == .overdue && $0.item.name == "Bath" }, "overdue bath listed")
            let planned = today.filter { $0.kind == .planned }.map(\.date)
            expect(planned == [date(2026, 10, 17, 14), date(2026, 10, 17, 17), date(2026, 10, 17, 20), date(2026, 10, 17, 23)], "planned feeds until midnight")
            expect(today.map(\.date) == today.map(\.date).sorted(), "timeline sorted")

            let yesterday = CareEngine.timeline(for: date(2026, 10, 16, 12), in: state, now: now, calendar: calendar)
            expect(yesterday.count == 1 && yesterday[0].kind == .done, "past day: only logged entries, nothing invented")
            let empty = CareEngine.timeline(for: date(2026, 10, 10, 12), in: state, now: now, calendar: calendar)
            expect(empty.isEmpty, "day with nothing logged is empty")

            // Deleting an item removes its log
            state.deleteItem(feed.id)
            expect(!state.events.contains { $0.itemID == feed.id }, "delete item removes its events")
        }

        // MARK: Validation
        do {
            var state = CareState()
            try! state.addItem(CareItem(kind: .care, name: "Feed", symbol: "drop.fill", intervalMinutes: 180, firstDue: Date()))
            do {
                try state.addItem(CareItem(kind: .care, name: "  feed ", symbol: "drop.fill", intervalMinutes: 120, firstDue: Date()))
                expect(false, "duplicate accepted")
            } catch {
                expect(error as? CareValidationError == .duplicateName("feed"), "duplicate name rejected")
            }
            do {
                try state.addItem(CareItem(kind: .care, name: "   ", symbol: "drop.fill", intervalMinutes: 120, firstDue: Date()))
                expect(false, "empty name accepted")
            } catch {
                expect(error as? CareValidationError == .missingName, "empty name rejected")
            }
            do {
                try state.addItem(CareItem(kind: .care, name: "Quick", symbol: "drop.fill", intervalMinutes: 15, firstDue: Date()))
                expect(false, "15-min interval accepted")
            } catch {
                expect(error as? CareValidationError == .intervalOutOfRange, "too-short interval rejected")
            }
            // Renaming an item to its own name is fine
            var feed = state.items[0]
            feed.notes = "Night feeds too"
            expect((try? state.updateItem(feed)) != nil, "update keeps its own name")
        }

        // MARK: Formatting and age
        do {
            expect(CareFormat.interval(180) == "Every 3 hours", "interval 3h")
            expect(CareFormat.interval(30) == "Every 30 min", "interval 30m")
            expect(CareFormat.interval(90) == "Every 1h 30m", "interval 1h30")
            expect(CareFormat.interval(60) == "Every hour", "interval 1h")
            expect(CareFormat.interval(1440) == "Once a day", "interval daily")
            expect(CareFormat.interval(2880) == "Every 2 days", "interval 2 days")
            expect(CareFormat.duration(70 * 60) == "1h 10m", "duration 1h10")
            expect(CareFormat.duration(42 * 60) == "42 min", "duration 42m")
            expect(CareFormat.duration(30) == "<1 min", "duration under a minute")
            let now = date(2026, 10, 17, 12)
            expect(CareFormat.relative(due: now.addingTimeInterval(-12 * 60), now: now) == "12 min late", "late")
            expect(CareFormat.relative(due: now.addingTimeInterval(20), now: now) == "due now", "due now")

            expect(CareEngine.ageDescription(birthDate: date(2026, 10, 17, 3), now: now, calendar: calendar) == "Born today", "born today")
            expect(CareEngine.ageDescription(birthDate: date(2026, 10, 12, 3), now: now, calendar: calendar) == "5 days old", "5 days")
            expect(CareEngine.ageDescription(birthDate: date(2026, 9, 5, 3), now: now, calendar: calendar) == "6 weeks old", "6 weeks")
            expect(CareEngine.ageDescription(birthDate: date(2026, 5, 10, 3), now: now, calendar: calendar) == "5 months old", "5 months")
            expect(CareEngine.ageDescription(birthDate: date(2025, 8, 1, 3), now: now, calendar: calendar) == "1 year 2 months old", "1y2m")
        }

        // MARK: Fixed times of day
        do {
            var state = CareState()
            // 8 AM and 8 PM, added at 2 PM: first due tonight.
            let med = CareItem(kind: .medicine, name: "Antibiotic", symbol: "pills.fill", intervalMinutes: 720, schedule: .times([1200, 480]), firstDue: date(2026, 10, 17, 14))
            try! state.addItem(med)
            expect(state.items[0].schedule == .times([480, 1200]), "times stored sorted")
            expect(CareEngine.nextDue(for: state.items[0], in: state, calendar: calendar) == date(2026, 10, 17, 20), "first slot after start")

            // Given 20 min late covers the 8 PM slot -> next is 8 AM tomorrow
            state.complete(med.id, at: date(2026, 10, 17, 20, 20), now: date(2026, 10, 17, 20, 20))
            expect(CareEngine.nextDue(for: state.items[0], in: state, calendar: calendar) == date(2026, 10, 18, 8), "late dose covers its slot")
            // Given 30 min early for 8 AM -> next is 8 PM, not 8 AM
            state.complete(med.id, at: date(2026, 10, 18, 7, 30), now: date(2026, 10, 18, 7, 30))
            expect(CareEngine.nextDue(for: state.items[0], in: state, calendar: calendar) == date(2026, 10, 18, 20), "early dose covers its slot")

            // Skipping a long-missed dose jumps to the next slot after now
            var missed = CareState()
            let vit = CareItem(kind: .medicine, name: "Vitamin D3", symbol: "sun.max.fill", intervalMinutes: 1440, schedule: .times([540]), firstDue: date(2026, 10, 15, 8))
            try! missed.addItem(vit)
            missed.skip(vit.id, now: date(2026, 10, 17, 12), calendar: calendar)
            expect(CareEngine.nextDue(for: missed.items[0], in: missed, calendar: calendar) == date(2026, 10, 18, 9), "skip daily: tomorrow 9 AM")

            // Today's timeline plans the remaining slots
            var plan = CareState()
            let thrice = CareItem(kind: .medicine, name: "Drops", symbol: "drop.fill", intervalMinutes: 480, schedule: .times([480, 840, 1200]), firstDue: date(2026, 10, 17, 9))
            try! plan.addItem(thrice)
            let planned = CareEngine.timeline(for: date(2026, 10, 17, 9), in: plan, now: date(2026, 10, 17, 9), calendar: calendar).map(\.date)
            expect(planned == [date(2026, 10, 17, 14), date(2026, 10, 17, 20)], "times: planned slots today")
            let fraction = CareEngine.remainingFraction(for: plan.items[0], due: date(2026, 10, 17, 14), now: date(2026, 10, 17, 11), calendar: calendar)
            expect(abs(fraction - 0.5) < 0.0001, "times ring uses gap since previous slot")

            // Daily time stays at 9 AM across DST
            var dst = CareState()
            let daily = CareItem(kind: .medicine, name: "Iron", symbol: "drop.fill", intervalMinutes: 1440, schedule: .times([540]), firstDue: date(2026, 10, 31, 12))
            try! dst.addItem(daily)
            expect(CareEngine.nextDue(for: dst.items[0], in: dst, calendar: calendar) == date(2026, 11, 1, 9), "9 AM after DST change")

            do {
                try state.addItem(CareItem(kind: .medicine, name: "Empty", symbol: "pills.fill", intervalMinutes: 60, schedule: .times([]), firstDue: Date()))
                expect(false, "no times accepted")
            } catch {
                expect(error as? CareValidationError == .missingTimes, "times required")
            }
        }

        // MARK: As needed
        do {
            let now = date(2026, 10, 17, 12)
            var state = CareState()
            let fever = CareItem(kind: .medicine, name: "Fever medicine", symbol: "thermometer.medium", intervalMinutes: 360, schedule: .asNeeded, firstDue: now)
            try! state.addItem(fever)
            expect(CareEngine.schedule(for: state, now: now).isEmpty, "as-needed not in the due schedule")
            expect(!state.items[0].sendsReminders, "as-needed never reminds")
            var prn = CareEngine.asNeeded(for: state, now: now)
            expect(prn.count == 1 && prn[0].lastGiven == nil && prn[0].okAfter == nil, "not given yet: OK now")

            state.complete(fever.id, at: date(2026, 10, 17, 10), now: now)
            prn = CareEngine.asNeeded(for: state, now: now)
            expect(prn[0].lastGiven == date(2026, 10, 17, 10) && prn[0].okAfter == date(2026, 10, 17, 16), "OK again 6h after last dose")
            prn = CareEngine.asNeeded(for: state, now: date(2026, 10, 17, 16, 1))
            expect(prn[0].okAfter == nil, "OK once the gap has passed")

            expect(state.skip(fever.id, now: now) == nil, "as-needed can't be skipped")
            state.snooze(fever.id, minutes: 15, now: now)
            expect(state.items[0].snoozedUntil == nil, "as-needed can't be snoozed")
            let timeline = CareEngine.timeline(for: now, in: state, now: now, calendar: calendar)
            expect(timeline.count == 1 && timeline[0].kind == .done, "as-needed: only logged doses in timeline")
        }

        // MARK: Course length
        do {
            var state = CareState()
            // Twice a day, last day 18 Oct (course ends at midnight starting 19 Oct).
            let end = date(2026, 10, 19, 0)
            let course = CareItem(kind: .medicine, name: "Antibiotic", symbol: "pills.fill", intervalMinutes: 720, schedule: .times([480, 1200]), firstDue: date(2026, 10, 17, 7), endDate: end)
            try! state.addItem(course)
            expect(CareEngine.schedule(for: state, now: date(2026, 10, 17, 7)).count == 1, "active during course")
            var now = date(2026, 10, 17, 8)
            for slot in [date(2026, 10, 17, 8), date(2026, 10, 17, 20), date(2026, 10, 18, 8)] {
                now = slot
                state.complete(course.id, at: slot, now: now)
            }
            expect(!CareEngine.isFinished(state.items[0], in: state, now: now, calendar: calendar), "last dose still to come")
            let planned = CareEngine.timeline(for: date(2026, 10, 18, 9), in: state, now: date(2026, 10, 18, 9), calendar: calendar).filter { $0.kind == .planned }
            expect(planned.count == 1, "no planned slot after the course ends")
            state.complete(course.id, at: date(2026, 10, 18, 20), now: date(2026, 10, 18, 20))
            expect(CareEngine.isFinished(state.items[0], in: state, now: date(2026, 10, 18, 20), calendar: calendar), "finished after last dose")
            expect(CareEngine.schedule(for: state, now: date(2026, 10, 18, 20), calendar: calendar).isEmpty, "finished items leave Today")
            expect(CareEngine.finished(for: state, now: date(2026, 10, 18, 20), calendar: calendar).count == 1, "listed as finished")
        }

        // MARK: Schedule kinds round-trip through saved files
        do {
            var state = CareState()
            try! state.addItem(CareItem(kind: .medicine, name: "A", symbol: "pills.fill", intervalMinutes: 720, schedule: .times([480, 1200]), firstDue: Date(timeIntervalSince1970: 1_000_000), endDate: Date(timeIntervalSince1970: 2_000_000), createdAt: Date(timeIntervalSince1970: 1_000_000)))
            try! state.addItem(CareItem(kind: .medicine, name: "B", symbol: "pills.fill", intervalMinutes: 360, schedule: .asNeeded, firstDue: Date(timeIntervalSince1970: 1_000_000), createdAt: Date(timeIntervalSince1970: 1_000_000)))
            let reloaded = try? CarePersistence.decode(CarePersistence.encode(state))
            expect(reloaded == state, "times, as-needed and end date saved and loaded")
        }

        // MARK: Caregiver title
        do {
            expect(BabyProfile(name: "Vedika", caregiverRole: "Mom").caregiverTitle == "Vedika's Mom", "Vedika's Mom")
            expect(BabyProfile(name: "Vedika", caregiverRole: " Dad ").caregiverTitle == "Vedika's Dad", "role trimmed")
            expect(BabyProfile(name: "Dhruvs", caregiverRole: "Mom").caregiverTitle == "Dhruvs' Mom", "name ending in s")
            expect(BabyProfile(name: "Vedika").caregiverTitle == nil, "no role, no title")
        }

        // MARK: Vaccination schedule
        do {
            let birth = date(2026, 9, 1, 15)
            let now = date(2026, 10, 17, 12)
            var state = CareState(baby: BabyProfile(name: "Vedika", birthDate: birth))
            state.startVaccineSchedule(.india, birthDate: birth, markPastAsGiven: true, now: now, calendar: calendar)
            let visits = VaccineEngine.visits(for: state.vaccines, calendar: calendar)
            expect(visits.first?.title == "At birth" && visits.first?.dueDate == date(2026, 9, 1, 0), "birth visit on birth day")
            expect(visits[1].title == "6 weeks" && visits[1].dueDate == date(2026, 10, 13, 0), "6 weeks = birth + 42 days")
            expect(visits.first(where: { $0.title == "9 months" })?.dueDate == date(2027, 6, 1, 0), "9 months by calendar month")
            expect(visits[0].isComplete && visits[1].isComplete, "past visits marked given when asked")
            let next = VaccineEngine.nextVisit(in: state, calendar: calendar)
            expect(next?.title == "10 weeks" && next?.doses.count == 6, "next visit is 10 weeks with 6 doses")
            expect(VaccineEngine.status(of: next!, now: now, calendar: calendar) == .upcoming, "10 Nov is 24 days away = upcoming")

            // Status thresholds
            expect(VaccineEngine.status(of: next!, now: date(2026, 11, 5, 9), calendar: calendar) == .dueSoon, "within 7 days = due soon")
            expect(VaccineEngine.status(of: next!, now: date(2026, 10, 20, 9), calendar: calendar) == .upcoming, "weeks away = upcoming")
            expect(VaccineEngine.status(of: next!, now: date(2026, 11, 12, 9), calendar: calendar) == .overdue, "after due day = overdue")
            expect(VaccineEngine.dueText(for: next!, now: date(2026, 11, 10, 9), calendar: calendar) == "Due today", "due today text")
            expect(VaccineEngine.dueText(for: next!, now: date(2026, 11, 12, 9), calendar: calendar) == "2 days overdue", "overdue text")

            // Mark the visit given
            state.setVisitGiven(next!, on: date(2026, 11, 10, 11))
            expect(VaccineEngine.nextVisit(in: state, calendar: calendar)?.title == "14 weeks", "moves on to 14 weeks")

            // Birth date change recalculates only untouched, not-given doses
            var moved = state.vaccines.first { $0.visit == "14 weeks" }!
            moved.dueDate = date(2026, 12, 20, 0)
            state.updateVaccine(moved)
            state.recalculateVaccineDates(birthDate: date(2026, 9, 3, 15), calendar: calendar)
            expect(state.vaccines.first { $0.id == moved.id }?.dueDate == date(2026, 12, 20, 0), "hand-edited date kept")
            expect(state.vaccines.first { $0.visit == "6 weeks" }?.dueDate == date(2026, 10, 13, 0), "given dose not moved")
            expect(state.vaccines.first { $0.name == "MMR 1" }?.dueDate == date(2027, 6, 3, 0), "untouched dose follows new birth date")

            // Custom vaccine
            state.addVaccine(name: "  Meningococcal ", dueDate: date(2027, 3, 1, 0))
            expect(state.vaccines.contains { $0.name == "Meningococcal" && $0.visit == "Added by you" }, "custom vaccine added")

            // Without "mark past as given" everything starts open
            var fresh = CareState()
            fresh.startVaccineSchedule(.india, birthDate: birth, markPastAsGiven: false, now: now, calendar: calendar)
            expect(VaccineEngine.nextVisit(in: fresh, calendar: calendar)?.title == "At birth", "nothing pre-marked")

            let reloaded = try? CarePersistence.decode(CarePersistence.encode(state))
            expect(reloaded?.vaccines.count == state.vaccines.count, "vaccines saved and loaded")
        }

        // MARK: Saved files from older builds load with defaults
        do {
            let json = """
            {"baby":{"name":"Baby"},"items":[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"Feed","intervalMinutes":180}],
             "events":[{"id":"7F9619FF-8B86-D011-B42D-00C04FC964FF","itemID":"6F9619FF-8B86-D011-B42D-00C04FC964FF","date":"2026-10-17T10:00:00Z"}]}
            """
            do {
                let state = try CarePersistence.decode(Data(json.utf8))
                expect(state.schemaVersion == CareState.currentSchemaVersion, "schema defaulted")
                expect(state.baby?.caregiverRole == "", "caregiver role defaults to empty")
                expect(state.vaccines.isEmpty, "vaccines default to empty")
                expect(state.items[0].kind == .care && state.items[0].symbol == "heart.fill" && state.items[0].remindersOn && state.items[0].schedule == .interval && state.items[0].endDate == nil, "item defaults")
                expect(state.events[0].kind == .done && state.events[0].note.isEmpty, "event defaults")
                // Saved files store whole seconds, so a reloaded file must save back unchanged.
                let saved = try CarePersistence.encode(state)
                let reloaded = try CarePersistence.decode(saved)
                let resaved = try CarePersistence.encode(reloaded)
                expect(resaved == saved, "saved file reloads unchanged")
            } catch {
                expect(false, "old file failed to load: \(error)")
            }
        }

        print(failures == 0 ? "All \(checks) checks passed." : "\(failures) of \(checks) checks failed.")
        exit(failures == 0 ? 0 : 1)
    }
}
