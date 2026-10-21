# 09 · Settings, storage, backup, sharing

Source: `Shared/AppPreferences.swift`, `ChildCareClock/SettingsView.swift`, `KeychainBackup.swift`, `Shared/PhotoStore.swift`, `CareReport.swift`.

## Settings and defaults

These live in a shared key-value store (App Group `UserDefaults`), so the widget and Siri read the same values.

| Key | Values | Default | Effect |
|---|---|---|---|
| `appearance` | system / light / dark | system | Theme |
| `soundMode` | daytime / always / off | **daytime** | In-app chimes. Daytime = silent 21:00–06:59. Haptics always play |
| `earlyReminderMinutes` | 0 / 5 / 15 / 30 | **5** | Extra heads-up notification before due (0 = off) |
| `warningMinutes` | 5 / 10 / 15 / 30 | **15** | When a row turns "due soon" (amber) |
| `medicineNudgesEnabled` | bool | **true** | Repeat medicine reminders at +10 and +20 min |
| `vaccineRemindersEnabled` | bool | **true** | Vaccine notifications |

## The baby's photo

- Optional. Chosen in onboarding or Settings; "Remove photo" clears it.
- Saved once as a **JPEG** (quality 0.82) with the longest side ≤ **700 px**, in the shared folder as `baby-photo.jpg`. The app, widget and backup all use that file.
- Shown in the Today header, the Settings avatar, and the Home Screen widgets. **Not** used as the app icon or in notifications (both decided against).

## Backup that survives a reinstall (Keychain)

- After every change, a copy of the state (JSON compressed with LZFSE) and the photo is written to the iOS **Keychain**. Keychain items stay on the phone even after the app is deleted.
- On the next install, the welcome screen offers **Restore {name}'s data** or **Start fresh**. Start fresh wipes the Keychain copy.
- This copy is not synced through iCloud Keychain. It moves to a new iPhone only via an encrypted or iCloud device backup.
- "Delete all data" in Settings also deletes the Keychain copy.

**Android equivalent:** there is no exact match, since app data is wiped on uninstall. Options:
1. **Android Auto Backup** (Google Drive, automatic, restored on reinstall or a new phone). It works with no code beyond `backup_rules.xml`. This is the recommendation.
2. Block Store for small data.
3. A manual export/import file.

Keep the Restore / Start fresh welcome screen if Auto Backup brings data back.

## Export

Settings → **Export my data** shares `BabyCareClock-backup.json`. It is the exact saved state (format in [04](04-data-model.md)). **There is no import yet.** An Android import of this file would let iPhone users switch phones (an idea).

## Delete all data

Removes the photo, the state file, every pending and delivered notification, and the Keychain copy, then returns to onboarding. It asks for confirmation first.

## Share a day (History → share)

- **Text** (see the example in [02](02-screens.md), section 4): a title "{Milu}'s day · {Tuesday, 21 Oct}", one line per entry (`✓`/`–`, time, name, dosage and note, "— skipped"), "Totals: Feed ×6, …", and a footer "Shared by {Milu's Mom} from Baby Care Clock".
- **Image:** the same as a light card 390 wide at 3×, with "Baby Care Clock" in the corner.
- Main use: showing the pediatrician.

## Privacy (what we promise users)

- No account, no ads, no analytics, no tracking. Nothing is uploaded.
- Data leaves the phone only when the user shares or exports it.
- The privacy policy is in `../AppStore/PRIVACY_POLICY.html` (to be hosted at rajathverse.com/babycareclock/privacy).
- **Android must keep these promises**, including "no analytics SDK". The Play Store Data Safety form becomes simple: "no data collected".
