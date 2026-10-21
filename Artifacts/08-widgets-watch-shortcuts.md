# 08 · Widgets, Apple Watch, Siri

## Widgets: "Next up"

Source: `ChildCareClockWidget/NextUpWidget.swift`. Gallery name "Next up", description "Your baby's photo and what's due next."

The widget reads the same saved file as the app, so it always shows the same schedule.

| Size | Shows |
|---|---|
| **Home small** | The baby's **photo fills the background** (or the app gradient if there's no photo). At the bottom, on a dark frosted panel: item icon and name, a live countdown, and a **Done** capsule button |
| **Home medium** | The photo on the left (rounded). On the right: the baby's name (or "Next up") and the next **3 items**, each with an icon, name, countdown and a round ✓ button |
| **Lock circular** | A ring counting down the current cycle with the item icon inside. When due: the icon only. Nothing scheduled: ✓ |
| **Lock rectangular** | Icon and name · countdown · "at 2:30 PM" |
| **Lock inline** | "{Feed} · 2:30 PM", or "All caught up" |

- Countdown: a live system timer until the due time, then "Due now".
- Empty states: "All caught up", or "Open Baby Care Clock to get started" if not set up.
- **The Done button works without opening the app.** It runs the same "log now" action as Siri and refreshes everything.
- **Refresh:** a timeline entry now and at each of the next 4 due times (so "Due now" appears on time), then a reload at the latest 30 min later. Any change in the app also reloads widgets.
- The photo is resized to at most 700 px because widgets reject large images.

**Android (Glance):** `GlanceAppWidget` small/medium. A countdown can use `Chronometer` in RemoteViews with `setCountDown(true)`. Lock Screen widgets don't exist on most Android phones; an ongoing notification would be the closest, but a persistent Lock Screen card was **rejected** (see [12](12-decisions-and-open-issues.md)), so skip it.

## Apple Watch app

Source: `ChildCareClockWatch/`, `ChildCareClock/WatchSync.swift`, `Shared/WatchPayload.swift`.

- Title: the caregiver title, the baby's name, or "Care Clock". Always dark, with its own soft palette.
- **Next up card:** "NEXT UP" / "OVERDUE", the item name, a relative time and a live timer, then **Done** and "Snooze 15 min".
- **Later** list. Tapping an item opens a detail view with the dosage, "Done now" and "Snooze 15 min". As-needed items are listed too.
- Empty states: "Open Baby Care Clock on your iPhone to get started." / "Nothing scheduled."
- **Sync:**
  - The iPhone sends a trimmed copy of the state on every change. It contains only each item's latest log plus the last 24 h of events, and no vaccines.
  - A Watch tap is applied on the Watch immediately (with a haptic) and sent to the iPhone as `{action: done|snooze, itemID, date}`, queued if the phone isn't reachable.
  - **The iPhone is the source of truth.**
- Not tested on a real Watch yet (open to-do).

**Android:** a Wear OS companion is optional. Use the Wearable Data Layer (`DataClient` for state, `MessageClient` for actions) with the same payload. Build it last.

## Siri and Shortcuts

Source: `Shared/CareIntents.swift`, `ChildCareClock/CareShortcuts.swift`.

| Intent | Phrases | What it does |
|---|---|---|
| **Log care item** (parameter: item) | "Log {item} in Baby Care Clock", "Mark {item} done in Baby Care Clock", "Log in Baby Care Clock" | Marks the item done now. Replies "Logged Feed. Next one is due at 5:30 PM." (as needed: "…The next dose is OK after 4:00 PM.") |
| **What's next** | "What's next in Baby Care Clock", "What's due in Baby Care Clock" | "Feed is next, in 1h 10m, at 2:30 PM. Then Vitamin D3 at 9:00 PM." / "Feed is due now." / "Nothing is scheduled right now." |

The item picker lists items that aren't finished and supports search by name. The widget's Done button uses the same Log intent.

**Android:** App Actions / Google Assistant shortcuts (`shortcuts.xml` with capabilities), or static and dynamic shortcuts on long-pressing the launcher icon ("Log feed"). Lower priority.

## How outside changes reach the app

Widget, Siri and Watch changes go through `CareActions.perform`:

1. load the saved state
2. apply the change
3. save
4. reschedule notifications
5. reload widgets
6. post a cross-process signal

The running app listens for that signal and reloads from disk. On Android a single repository (Room or DataStore) observed by the UI does the same.
