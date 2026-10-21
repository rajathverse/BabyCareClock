# Baby Care Clock: handoff pack

This folder explains the whole iOS app for someone who **can't run it** (no Xcode), so it can be rebuilt on Android and improved. Everything here comes from the Swift source in this repo. Where a doc states a rule, the source file is named so you can check it.

## What the app is

A calm reminder and logging app for new parents, mainly moms. You set how often each thing happens, such as a feed every 3 hours, Vitamin D3 at 9 AM, or fever medicine "as needed, at least 6 h apart". The app tells you when each one is due, you tap **Done**, and the next due time is worked out from what you logged. No account, no server, no internet. Everything stays on the phone.

## Reading order

| # | Doc | Read it for |
|---|---|---|
| 1 | [01-product.md](01-product.md) | Who it's for, the core loop, the feature list |
| 2 | [02-screens.md](02-screens.md) | Every screen, every tap and swipe, the exact text on screen |
| 3 | [03-design-system.md](03-design-system.md) | Colors, type, shapes, icons, sounds, haptics |
| 4 | [04-data-model.md](04-data-model.md) | What is saved, field by field, with a sample JSON |
| 5 | [05-scheduling-logic.md](05-scheduling-logic.md) | **The core.** How due times are calculated |
| 6 | [06-notifications.md](06-notifications.md) | Which reminders are sent, when, and their wording |
| 7 | [07-vaccines.md](07-vaccines.md) | The vaccination schedule and its rules |
| 8 | [08-widgets-watch-shortcuts.md](08-widgets-watch-shortcuts.md) | Home/Lock Screen widgets, Apple Watch, Siri |
| 9 | [09-settings-storage.md](09-settings-storage.md) | Settings and defaults, photo, backup/restore, export, share |
| 10 | [10-android-mapping.md](10-android-mapping.md) | The Android equivalent of each iOS piece, and a build order |
| 11 | [11-test-cases.md](11-test-cases.md) | 106 engine checks as given → expect cases, to verify the Android engine |
| 12 | [12-decisions-and-open-issues.md](12-decisions-and-open-issues.md) | What was decided, what was rejected, known gaps, ideas |

`screenshots/` has dark-mode screenshots of every app screen. They also appear inside [02-screens.md](02-screens.md).

## Try something today, without Xcode

`../baby-care-scheduler.html` is the **original web version** ("Milu Care Clock"). Open it in Chrome on a laptop or Android phone to get a feel for the idea. The iOS app has moved well past it, so treat the docs here as the source of truth, not the web page.

## Where the real code is

| Folder | What's in it |
|---|---|
| `../Shared/` | Platform-neutral logic: models, **scheduling engine**, vaccines, notifications, theme. Start here when porting |
| `../ChildCareClock/` | The iPhone app screens (SwiftUI) and glue code |
| `../ChildCareClockWidget/` | Home Screen and Lock Screen widgets |
| `../ChildCareClockWatch/` | Apple Watch app |
| `../Verification/EngineSmokeTest.swift` | The engine tests (run with `../verify_engine.sh` on a Mac) |
| `../AppStore/` | Store listing text, privacy policy, support page, submission guide |

The engine (`Shared/CareEngine.swift`, `CareModels.swift`, `Vaccines.swift`) is plain logic with no UI. It translates almost line for line to Kotlin.

## Facts at a glance

- iOS 17+, iPhone only, portrait. watchOS companion app.
- Bundle ID `com.rajathverse.childcareclock`. Display name **Baby Care Clock**.
- One baby per install (deliberate, see doc 12).
- English only for now.
