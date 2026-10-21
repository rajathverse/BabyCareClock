# 04 · Data model

Source: `Shared/CareModels.swift`, `Shared/Vaccines.swift`, `Shared/CarePersistence.swift`.

## Big idea: store the log, derive the schedule

The app **never stores a "next due" time**. It stores the items and the list of things done (events), and calculates every due time from them on the fly. Editing or deleting a log entry therefore always gives a correct schedule, with no sync bugs. Keep this on Android.

The only stored timing hints are `firstDue` (used before anything is logged), `snoozedUntil` and `endDate`.

## Storage

- One JSON file, `care-state.json`, in a folder `ChildCareClock/` in the shared App Group container (so the widget can read it). If the App Group is unavailable, it goes in Application Support.
- JSON: keys sorted, pretty-printed, **dates as ISO-8601 strings in UTC with whole seconds** (`"2026-10-21T08:05:00Z"`).
- Written atomically, with file protection "until first unlock". This lets notifications and widgets read it while the phone is locked.
- If a file can't be decoded, it is renamed to `care-state.json.unreadable` instead of being overwritten.
- **Every field except ids and names is optional when loading.** Older files load with defaults (tested). Keep that tolerance on Android.
- Settings live in a separate key-value store (see [09](09-settings-storage.md)). The photo is a separate JPEG file.

## `CareState` (the root)

| Field | Type | Notes |
|---|---|---|
| `schemaVersion` | Int | Currently `1` |
| `baby` | BabyProfile? | `null` means not set up, so the app shows onboarding |
| `items` | [CareItem] | The care plan |
| `events` | [CareEvent] | Everything logged (done or skipped), for all time |
| `vaccines` | [VaccineDose] | Empty until vaccinations are set up |

## `BabyProfile`

| Field | Type | Notes |
|---|---|---|
| `name` | String | Required, trimmed |
| `birthDate` | Date? | Optional |
| `caregiverRole` | String | "Mom", "Dad", "Grandma", "Grandpa", "Nanny", any typed text, or "" |

Derived **caregiver title**: `"{name}'s {role}"`, or `"{name}' {role}"` if the name ends in "s". It is `nil` when there's no role (the UI then shows the baby's name).

## `CareItem`

| JSON key | Type | Default when missing | Notes |
|---|---|---|---|
| `id` | UUID string | (required) | |
| `kind` | `"medicine"` \| `"care"` | `care` | Drives color and grouping |
| `name` | String | (required) | Unique, case-insensitive, trimmed |
| `symbol` | String | `pills.fill` / `heart.fill` | SF Symbol name (map to Material on Android) |
| `intervalMinutes` | Int | (required) | Interval: the gap. As needed: the **minimum gap**. Set times: `max(30, 1440 / count)`, for display only |
| `scheduleKind` | `"interval"` \| `"times"` \| `"asNeeded"` | `interval` | |
| `times` | [Int] | `[]` | Only for `times`: **minutes after midnight**, unique and sorted, e.g. `[480, 1200]` = 8 AM and 8 PM |
| `dosage` | String | `""` | e.g. "1 drop" |
| `notes` | String | `""` | |
| `remindersOn` | Bool | `true` | Ignored for as-needed (never reminds) |
| `firstDue` | Date | `createdAt` | When it's due if nothing has been logged yet |
| `snoozedUntil` | Date? | null | Pushes the due time out; cleared by the next Done/Skip |
| `endDate` | Date? | null | Exclusive end of a course = **midnight after the last day** |
| `createdAt` | Date | now | |

Limits: interval 30 min to 7 days (10 080 min); up to **8** times per day.

## `CareEvent` (a log entry)

| JSON key | Type | Default | Notes |
|---|---|---|---|
| `id` | UUID | (required) | |
| `itemID` | UUID | (required) | Deleting an item deletes its events |
| `date` | Date | (required) | When it was done. For a skip: the slot it skipped |
| `kind` | `"done"` \| `"skipped"` | `done` | |
| `note` | String | `""` | Trimmed |

## `VaccineDose`

| JSON key | Type | Default | Notes |
|---|---|---|---|
| `id` | UUID | (required) | |
| `name` | String | (required) | e.g. "Rotavirus 1" |
| `visit` | String | `""` | Group label, e.g. "6 weeks". Custom ones get "Added by you" |
| `dueDate` | Date | (required) | Start of day |
| `givenDate` | Date? | null | Set = given |
| `note` | String | `""` | "hospital, batch no." |
| `ageMonths`, `ageWeeks` | Int? | null | Age when due, used to recalculate if the birth date changes |
| `dueDateEdited` | Bool | `false` | `true` once the parent changes the date by hand (it is then never auto-moved) |

## Starter templates (onboarding and Quick pick)

| Kind | Name | Icon | Interval | Dosage hint |
|---|---|---|---|---|
| care | Feed | `drop.fill` | 3 h | |
| care | Diaper change | `sparkles` | 3 h | |
| care | Nap | `moon.zzz.fill` | 4 h | |
| care | Tummy time | `figure.and.child.holdinghands` | 4 h | |
| care | Kangaroo care | `heart.fill` | 8 h | |
| care | Bath | `bathtub.fill` | 24 h | |
| care | Play time | `teddybear.fill` | 8 h | |
| care | Walk outside | `stroller.fill` | 24 h | |
| medicine | Vitamin D3 | `sun.max.fill` | 24 h | e.g. 1 drop |
| medicine | Iron drops | `eyedropper.halffull` | 24 h | e.g. 0.5 ml |
| medicine | Calcium syrup | `cross.vial.fill` | 24 h | e.g. 2.5 ml |
| medicine | Multivitamin | `pills.fill` | 24 h | e.g. 0.5 ml |
| medicine | Probiotic | `leaf.fill` | 24 h | e.g. 5 drops |

All 24 selectable icons: `drop.fill, waterbottle.fill, sparkles, moon.zzz.fill, figure.and.child.holdinghands, heart.fill, bathtub.fill, teddybear.fill, stroller.fill, sun.max.fill, eyedropper.halffull, cross.vial.fill, pills.fill, pill.fill, leaf.fill, syringe.fill, thermometer.medium, bandage.fill, hands.and.sparkles.fill, music.note, book.fill, fork.knife, cup.and.saucer.fill, star.fill`.

## Sample file

```json
{
  "baby" : { "birthDate" : "2026-09-01T09:30:00Z", "caregiverRole" : "Mom", "name" : "Milu" },
  "events" : [
    { "date" : "2026-10-21T02:35:00Z", "id" : "0B6E2C1A-6C1F-4B7A-9D2E-1F0A3C5D7E91",
      "itemID" : "A1F1C0D2-1111-4C3B-8E2A-000000000001", "kind" : "done", "note" : "Left side, 15 min" },
    { "date" : "2026-10-21T03:30:00Z", "id" : "0B6E2C1A-6C1F-4B7A-9D2E-1F0A3C5D7E92",
      "itemID" : "A1F1C0D2-1111-4C3B-8E2A-000000000002", "kind" : "done", "note" : "" }
  ],
  "items" : [
    { "createdAt" : "2026-10-15T04:00:00Z", "dosage" : "", "firstDue" : "2026-10-15T07:00:00Z",
      "id" : "A1F1C0D2-1111-4C3B-8E2A-000000000001", "intervalMinutes" : 180, "kind" : "care",
      "name" : "Feed", "notes" : "", "remindersOn" : true, "scheduleKind" : "interval", "symbol" : "drop.fill" },
    { "createdAt" : "2026-10-15T04:00:00Z", "dosage" : "1 drop", "firstDue" : "2026-10-15T04:00:00Z",
      "id" : "A1F1C0D2-1111-4C3B-8E2A-000000000002", "intervalMinutes" : 1440, "kind" : "medicine",
      "name" : "Vitamin D3", "notes" : "", "remindersOn" : true, "scheduleKind" : "times",
      "symbol" : "sun.max.fill", "times" : [ 540 ] },
    { "createdAt" : "2026-10-19T10:00:00Z", "dosage" : "2.5 ml", "endDate" : "2026-10-23T18:30:00Z",
      "firstDue" : "2026-10-19T10:00:00Z", "id" : "A1F1C0D2-1111-4C3B-8E2A-000000000003",
      "intervalMinutes" : 720, "kind" : "medicine", "name" : "Antibiotic", "notes" : "After food",
      "remindersOn" : true, "scheduleKind" : "times", "symbol" : "pills.fill", "times" : [ 480, 1200 ] },
    { "createdAt" : "2026-10-19T10:00:00Z", "dosage" : "2.5 ml", "firstDue" : "2026-10-19T10:00:00Z",
      "id" : "A1F1C0D2-1111-4C3B-8E2A-000000000004", "intervalMinutes" : 360, "kind" : "medicine",
      "name" : "Fever medicine", "notes" : "", "remindersOn" : true, "scheduleKind" : "asNeeded",
      "symbol" : "thermometer.medium" }
  ],
  "schemaVersion" : 1,
  "vaccines" : [
    { "ageMonths" : 0, "ageWeeks" : 10, "dueDate" : "2026-11-09T18:30:00Z", "dueDateEdited" : false,
      "id" : "C0FFEE00-0000-4000-8000-000000000001", "name" : "Rotavirus 2", "note" : "", "visit" : "10 weeks" }
  ]
}
```

(The times are UTC. In India, `2026-11-09T18:30:00Z` is midnight local time on 10 Nov.)

The same format is what **Settings → Export my data** produces. If Android reads and writes it unchanged, users could move between platforms.
