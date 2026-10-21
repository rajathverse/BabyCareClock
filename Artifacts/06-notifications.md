# 06 · Notifications

Source: `Shared/NotificationScheduler.swift`, `ChildCareClock/ChildCareClockApp.swift` (action handling).

All reminders are **local notifications** scheduled on the phone. There is no server and no push, and they work offline.

## The rebuild-everything approach

Whenever anything changes, the app **deletes every pending notification and schedules them all again** from the current state. That makes them impossible to get out of sync.

A full reschedule happens:
- after every change made in the app (Done, Snooze, Skip, add/edit/delete, vaccines, restore)
- when the app opens or comes back to the foreground
- when a reminder setting changes (early heads-up, medicine repeats, vaccine reminders)
- after a change made from outside the app: the widget's Done button, Siri, or the Watch (via `CareActions.perform`)

## What gets scheduled for each item

Only items that **send reminders**: `remindersOn == true` and not *as needed*, and not finished.
Only the **next** due time (`nextDue`) of each item is used.

| Reminder | When | Condition | Title | Body |
|---|---|---|---|---|
| **Due** | at `due` | `due` is in the future | "{Feed} is due now" | "Time for {Milu}'s {feed}." + " · {dosage}" if set (no baby name: "Time for {feed}.") |
| **Early heads-up** | `due − early` | Setting ≠ Off (default **5 min**) and that time is in the future | "{Feed} in 5 min" | "Coming up at 2:30 PM." |
| **Medicine repeat 1** | `due + 10 min` | Medicine only, setting "Repeat medicine reminders" on (default), time in the future | "{Iron drops} is still due" | "It was due at 2:30 PM. Tap Done once it's given." |
| **Medicine repeat 2** | `due + 20 min` | Same | Same | Same |

Notes:
- The item name is lower-cased in the due body ("Time for Milu's diaper change.").
- If a medicine is already overdue when the reschedule runs (say, 5 min late), the due reminder is not re-sent, but the +10/+20 repeats still are if they are in the future.
- Each reminder is a one-shot calendar trigger to the second. Nothing repeats by itself.
- Every reminder for an item shares a thread id (the item id), so iOS groups them.
- Notification ids: `due-{itemId}`, `early-{itemId}`, `nudge-1-{itemId}`, `nudge-2-{itemId}`.
- The sound is the system default. The in-app chime setting doesn't affect notifications.
- The baby's photo is **not** shown in notifications (decided).

## Done / Snooze buttons on the notification

- Category `CARE_DUE` has two actions: **Done** (check-mark icon) and **Snooze 15 min** (clock icon).
- Both run **without opening the app**. The user long-presses or expands the notification to see them.
- Done marks the item done now (like tapping Done in the app). Snooze adds 15 min (see [05](05-scheduling-logic.md)). Both then trigger a full reschedule.
- Tapping the notification body just opens the app.
- After Done, Snooze, Skip or delete, banners already delivered for that item are removed from Notification Center.
- If the app is open, the notification still shows as a banner with sound.

## Vaccination reminders

- Setting "Vaccination reminders" (default on).
- For the **next 2 visits** that still have doses to give:

| When | Title | Body |
|---|---|---|
| 3 days before, 9:00 AM | "Vaccination reminder" | "{Milu}'s {10 weeks} vaccines are due on {Monday 10 November}. Time to book the visit." |
| On the day, 9:00 AM | "Vaccination reminder" | "{Milu}'s {10 weeks} vaccines are due today ({6 vaccines})." |

These have no action buttons. Past times are skipped.

## Permission

The app asks for alerts, sounds and badges:
- in onboarding, at step 4 ("Allow reminders")
- in Settings, if it hasn't been asked yet
- again after a restore, since permission doesn't survive a reinstall

If notifications are denied, Settings shows a red row that opens the system notification settings.

**Time Sensitive** notifications were removed because the free Apple signing team doesn't allow them. They will come back with the paid developer account. Android equivalent: a high-importance channel.

## iOS limit

iOS keeps at most 64 pending local notifications. The worst case here is 4 per item plus 4 for vaccines, which is well under that for a realistic plan.

## Android notes

- Use `AlarmManager.setExactAndAllowWhileIdle` (needs the exact-alarm permission on Android 12+, or `USE_EXACT_ALARM` for reminder apps) or `setAlarmClock`. WorkManager is **not** precise enough for medicine times.
- Re-run the "rebuild everything" step after **reboot** (`BOOT_COMPLETED`), **time or time zone change**, and **app update**. iOS does this for you; Android doesn't.
- Done/Snooze become notification actions handled by a `BroadcastReceiver`. It should apply the change to the stored state, reschedule, and update the widget, without opening an activity.
- Ask for `POST_NOTIFICATIONS` on Android 13+.
- Watch out for OEM battery optimisation (Xiaomi, Oppo, Vivo, Samsung), which can kill alarms. Consider a one-time "allow background" helper screen, since many users in India have these phones.
