# Baby Care Clock — native iOS (SwiftUI)

> **New here, or building the Android version?** Start with the handoff pack in [`Artifacts/`](Artifacts/README.md): screens, design, data model, scheduling rules and test cases.

Baby Care Clock is an iPhone app that gives parents gentle reminders for feeds, diapers, naps, vitamins and medicines. It is a native SwiftUI rebuild of the original "Milu Care Clock" web app (`baby-care-scheduler.html`, still in this folder). The web app is only the behaviour reference; nothing is embedded in a WebView. The scheduling rules live in a separate plain-Swift engine with its own smoke test. The UI uses soft pastel glass panels with full light and dark mode.

## What's in the app

- **Onboarding:** baby's name, birth date and optional photo, a choice of starter items with sensible default repeats, and the notification permission prompt.
- **Today:**
  - A "Next up" card with a countdown ring and a big **Done** button
  - A list of everything else, ordered by due time
  - Tap a row to log it now or at an earlier time, with an optional note
  - Swipe a row for Done / Snooze / Skip, or long-press it for all options
  - An Undo toast after every action
- **History:**
  - A day strip covering the last 60 days, plus a calendar jump
  - A timeline of what was done, skipped, overdue and still planned today
  - Daily totals
  - Tap an entry to edit its time or note; swipe to delete it
  - Share the day as text or as an image
- **Care Plan:**
  - Medicines and care activities, each with an SF Symbol icon
  - Three ways to repeat:
    - **Interval**: every X hours (30 min to 7 days, counted from the last time it was done)
    - **At set times** of day (e.g. 8 AM and 8 PM)
    - **As needed**: no reminders, and Today shows "OK to give" or "Wait until 5:06 PM", with a warning if a dose is logged too soon
  - Optional **course length** (3/5/7/10/14 days or a chosen last day); finished items move to a "Finished" section with their history kept
  - First due time: due now, already done at a past time, or due later
  - Dosage and notes
  - Reminders on or off per item
  - Duplicate names are rejected
- **Notifications:**
  - Sent at each item's due time
  - **Done** and **Snooze 15 min** buttons work without opening the app
  - Medicines not marked done are reminded again 10 and 20 minutes later (Settings → Repeat medicine reminders)
  - Early heads-up 5 minutes before (default), or 15 / 30 minutes, or off
- **Widgets:**
  - Home Screen small widget: the baby's photo with the next item and a countdown
  - Home Screen medium widget: the photo with the next three items
  - Lock Screen widgets: circular, rectangular and inline
- **Done from anywhere:** the Home Screen widget and the due-time notification both have **Done** buttons, so an item can be logged without opening the app.
- **Vaccinations** (Care Plan → Vaccinations):
  - The India (IAP) schedule from birth to 6 years, worked out from the birth date, or your own list
  - Mark a single vaccine or a whole visit as given
  - Edit due dates and add notes, such as the hospital or batch number
  - Reminders 3 days before and on the morning of each visit, plus a card on Today when a visit is less than a week away
- **Siri:** "Log feed in Baby Care Clock", "Log in Baby Care Clock" (Siri asks which item), "What's next in Baby Care Clock".
- **Apple Watch app:** shows what's next with a countdown, plus Done and Snooze buttons. It syncs with the iPhone; taps made while the iPhone is out of reach are delivered later. iPhone reminders also appear on the Watch with their Done and Snooze buttons.
- **Caregiver role:** "Vedika's Mom", "Vedika's Dad" and so on, shown in the Today header and on shared summaries.
- **Settings:**
  - Baby profile
  - Reminder options
  - Theme: System / Light / Dark
  - Sounds for Done / Snooze taps: Daytime only (default, quiet 9 PM – 7 AM), Always or Off
  - Export a JSON backup, or delete all data
- **Survives reinstalling:** a copy of the data and photo is kept in the iPhone's Keychain (never synced or uploaded). After a reinstall, the welcome screen offers "Restore Vedika's data" or "Start fresh". Delete all data removes this copy too.
  - Privacy and medical disclaimer

## Open and run in Xcode

1. Double-click `ChildCareClock.xcodeproj` (requires Xcode 16 or newer).
2. Choose the **ChildCareClock** scheme and an iPhone simulator, then press **Run** (⌘R).
3. On a physical iPhone, select your team under **Signing & Capabilities** for both targets.
   - A free Personal Team cannot sign App Groups. See the note at the end of `AppStore/SUBMISSION_GUIDE.md`.

The app targets iOS 17+, iPhone only, portrait. It needs no server, account or internet connection.

## Verify the scheduling engine

```bash
./verify_engine.sh
```

The smoke test runs 82 checks covering:

- first due times
- backdated completions, where the latest log wins
- future logs being clamped to now
- delete/edit/interval-change recalculation
- snooze and skip
- set-time schedules (early/late doses, DST)
- as-needed minimum gaps
- course end dates
- status thresholds
- interval maths across a DST change
- the day timeline, including that past days never get invented "missed" slots
- name and interval validation
- formatting and age text
- loading files saved by older builds

## Where to look in the source

| Folder / file | What it does |
|---|---|
| `Shared/CareModels.swift` | Baby, care item, logged event and the saved state (with backward-compatible decoding), plus templates |
| `Shared/CareEngine.swift` | Scheduling rules: next due (derived from the log, never stored), status, timeline, snooze, skip, validation and formatting |
| `ChildCareClock/KeychainBackup.swift` | The Keychain copy that brings data back after a reinstall |
| `Shared/CarePersistence.swift` | JSON storage in the App Group container shared with the widget |
| `Shared/PhotoStore.swift` | The baby photo, downscaled for the widget |
| `Shared/Theme.swift` | Soft pastel palette (light/dark), background, `glassPanel`, `SymbolBadge` |
| `Shared/CareLiveActivity.swift` | Only used to end the Lock Screen countdown left running by older builds |
| `ChildCareClock/CareViewModel.swift` | UI actions → engine → storage → notifications, widget and Watch, plus undo |
| `ChildCareClock/NotificationScheduler.swift` | Local notifications with Done / Snooze actions |
| `ChildCareClock/TodayView.swift`, `HistoryView.swift`, `CarePlanView.swift` | The three tabs |
| `ChildCareClock/ItemEditorSheet.swift`, `LogSheets.swift`, `OnboardingView.swift`, `SettingsView.swift` | Sheets and onboarding |
| `ChildCareClock/CareReport.swift` | Shareable day summary (text and image) |
| `ChildCareClockWidget/` | Home Screen and Lock Screen widgets (with Done buttons) |
| `ChildCareClockWatch/` | Apple Watch app (`WatchStore` syncs with `ChildCareClock/WatchSync.swift`) |
| `Shared/Vaccines.swift` | Vaccine doses, the IAP schedule and due-date rules |
| `Shared/CareIntents.swift`, `ChildCareClock/CareShortcuts.swift` | Siri / Shortcuts actions and phrases |
| `Shared/CareActions.swift` | Changes made by the widget, Siri or the Watch, plus the signal that tells the app to reload |
| `Config/` | Entitlements (App Group) and the widget's Info.plist |
| `AppStore/` | Listing text, privacy policy and a step-by-step submission guide |

## Behaviour notes

- Due times are always calculated from the most recent log, so editing or deleting an entry, or changing an item's repeat, updates the schedule immediately.
- Skipping keeps the rhythm: the next due time becomes the first scheduled slot after now.
- Logging an older dose never moves the schedule backwards; the latest log wins.
- Changes from the web app:
  - The template defaults are fixed: vitamins repeat daily rather than every 3 hours.
  - Backdating works for any time in the past 7 days.
  - Past days with nothing logged no longer show invented "Missed" slots.
  - Reminders now arrive even when the app is closed.

## Original web app (PWA)

`baby-care-scheduler.html`, `manifest.json`, `sw.js` and `icons/` are the original Milu Care Clock PWA (hosted at milucareclock.com). They are kept unchanged for reference and are not part of the iOS build.
