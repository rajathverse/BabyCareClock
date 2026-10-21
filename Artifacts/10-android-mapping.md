# 10 · iOS → Android mapping

This is a suggested Android stack and build order. It is a recommendation, not a requirement; change it to suit you.

## Stack

| Concern | iOS (today) | Android (suggested) |
|---|---|---|
| Language / UI | Swift, SwiftUI | **Kotlin, Jetpack Compose**, Material 3 with custom colors from [03](03-design-system.md) |
| Architecture | `CareViewModel` (one shared view model) → pure `CareEngine` | `ViewModel` + a **repository** that owns `CareState`, exposed as a `StateFlow`. A pure Kotlin `CareEngine` with no Android imports |
| Storage | One JSON file + `UserDefaults` | **The same JSON** with kotlinx.serialization in a file or DataStore (keeps export compatible), plus Preferences DataStore for settings. Room is optional and not needed at this size |
| Dates | `Date`, `Calendar` | `java.time` (`Instant` for stored times, `ZonedDateTime` / `LocalTime` for set times) |
| Reminders | `UNUserNotificationCenter` calendar triggers | **`AlarmManager.setExactAndAllowWhileIdle`** + `NotificationManager`. A receiver for alarms and actions. Reschedule on boot, time change and update |
| Notification actions | `UNNotificationAction` Done / Snooze | `NotificationCompat.Action` → `BroadcastReceiver` (no UI) |
| Widgets | WidgetKit (+ interactive Done button) | **Jetpack Glance** with `actionRunCallback` for Done |
| Lock Screen widgets | accessory widgets | Not available on most phones. Skip |
| Watch | watchOS + WatchConnectivity | Wear OS + Data Layer (optional, last) |
| Voice | App Intents / Siri | App Actions / static shortcuts (optional) |
| Reinstall backup | Keychain copy | **Auto Backup** (`backup_rules.xml`) |
| Photo | PhotosPicker, JPEG ≤ 700 px | Photo Picker (`PickVisualMedia`), same resize |
| Share | `ShareLink` text / image | `Intent.ACTION_SEND` text, and a rendered bitmap via `FileProvider` |
| Sounds | `AVAudioPlayer`, ambient session | `SoundPool` with the same 3 WAVs |
| Haptics | UIKit feedback generators | `HapticFeedbackConstants` / `VibrationEffect` |
| Icons | SF Symbols | Material Symbols Rounded (mapping in [03](03-design-system.md)) |
| Font | SF Pro Rounded | Nunito / Quicksand (Google Fonts) |
| Min OS | iOS 17 | Suggest **minSdk 26** (Android 8), target the latest |

## Gestures and controls

| iOS | Android |
|---|---|
| Swipe row right → Done, left → Skip/Snooze | `SwipeToDismissBox`, or a custom swipe with revealed actions |
| Long-press menu | `combinedClickable(onLongClick)` → `DropdownMenu` |
| Bottom sheets (`.sheet`) | `ModalBottomSheet`, or full-screen dialogs for the editor |
| Segmented control | `SingleChoiceSegmentedButtonRow` |
| Wheel date-time picker | Material `DatePicker` + `TimePicker` dialogs |
| Toast with Undo | `Snackbar` with an action ("Undo"), 5 s |
| Tab bar | `NavigationBar` with 3 items |

## Suggested build order

1. **Engine + tests.** Port `CareModels`, `CareEngine` and `Vaccines` to pure Kotlin and port the 106 cases in [11](11-test-cases.md) to JUnit. Nothing else starts until these pass.
2. **Storage.** JSON load/save with lenient defaults. Load the sample in [04](04-data-model.md) and an iOS export file.
3. **Today + Log sheet + Care Plan + editor.** The daily loop.
4. **Notifications.** Exact alarms, Done/Snooze actions, reboot handling, the rebuild-all strategy. **Test on a Xiaomi or Samsung with battery saver on.**
5. **Onboarding + Settings.**
6. **History** (timeline, edit, share).
7. **Vaccinations.**
8. **Widgets** (Glance small and medium with Done).
9. Auto Backup + Restore/Start fresh, export (and **import**, which would be new).
10. Optional: Wear OS, App Actions.

## Things that are easy to get wrong

- **Interval vs set-times time math:** intervals add real seconds (`Instant.plus`). Set times use local wall-clock slots. DST tests exist for both.
- **The latest event wins**, including skips. Use `max by date`, not "last in the list".
- **Future Done times are clamped to now.**
- The **set-times grace window** is easy to miss and breaks "given 20 min late" (see [05](05-scheduling-logic.md)).
- `endDate` is **exclusive** (the midnight after the last day).
- Stored dates are UTC ISO-8601 with **whole seconds**. Truncate milliseconds before saving, or the iOS round-trip test breaks.
- Name uniqueness ignores case and surrounding spaces.
