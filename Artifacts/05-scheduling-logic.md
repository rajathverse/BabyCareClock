# 05 · Scheduling logic (the core)

Source: `Shared/CareEngine.swift` (≈400 lines, no UI). Port this first, then run the cases in [11](11-test-cases.md) against it.

All times use the phone's **local calendar and time zone**. *Interval* items count **real elapsed time** (3 h is always 3 real hours, even across a DST change). *Set-times* items follow the **wall clock** (9 AM stays 9 AM after DST).

## 1. When is an item next due? `nextDue(item)`

`latest` = the item's most recent event by date, **done or skipped**.

```
switch item.schedule:
  interval:
      base = latest ? latest.date + interval : item.firstDue
  times(list):
      if latest: base = first slot STRICTLY AFTER (latest.date + grace(list))
      else:      base = first slot AT OR AFTER item.firstDue
  asNeeded:
      return latest ? latest.date + interval : "long ago" (i.e. OK now)   // snooze ignored

if item.snoozedUntil != null and snoozedUntil > base: return snoozedUntil
return base
```

### Set-times helpers
- **slot** = a clock time from `times` on some calendar day.
- **grace(times)** = 60 min, or **half of the smallest gap** between consecutive times (counting the wrap past midnight), whichever is smaller. With one time per day, the grace is 60 min.
  - `[480, 1200]` (8 AM, 8 PM): smallest gap 12 h → grace 60 min.
  - `[480, 540]` (8, 9 AM): gap 60 min → grace 30 min.
- **Why grace:** a dose given a bit early or late "covers" the slot it was meant for.
  - Given at 8:20 PM for the 8 PM slot → next is 8 AM tomorrow, not 8 PM again.
  - Given at 7:30 AM for 8 AM → 7:30 + 1 h = 8:30 → next slot after that is 8 PM.
- **firstSlot(after, inclusive):** search the slots within the next 3 days. If there are none, return `after + 1 day`.
- **followingSlot(due):** interval/asNeeded: `due + interval`. Times: the first slot strictly after `due + grace`.

## 2. Status of a due item

```
remaining = due - now
remaining <= 0                     → OVERDUE
remaining <= warningMinutes * 60   → DUE SOON      (warningMinutes setting, default 15)
otherwise                          → UPCOMING
```
Exactly at the due time counts as overdue.

## 3. Countdown ring fraction

```
cycleStart = interval/asNeeded: due - interval
             times: the previous slot before due (searched within 2 days), else due - 1 day
fraction   = clamp((due - now) / (due - cycleStart), 0, 1)     // 1 = just done, 0 = due now
```
The UI draws at least 2 %, and an overdue ring is drawn full and coral.

## 4. Lists shown on Today

- **Scheduled list** = items that are *not as-needed* and *not finished*, sorted by `nextDue` (ties broken by name A→Z). The first one is the hero card; the rest go under **Later**.
- **As-needed list** = as-needed items that aren't finished, sorted by name. For each:
  - `lastGiven` = latest event date
  - `okAfter` = `lastGiven + interval` **only if that's still in the future**, else null (shows "OK to give")
- **Finished** (shown in Care Plan):
  - Items with an `endDate`.
  - As needed: finished once `now ≥ endDate`.
  - Scheduled: finished once `nextDue ≥ endDate` (no more doses fall inside the course).

## 5. Actions (all of them change the state, which is then saved and synced)

### Done: `complete(item, at: date, note)`
1. `when = min(date, now)`. **A future time is treated as now.**
2. Delete this item's **skipped** events dated after `when` (a later real dose replaces a skip).
3. Add event `{kind: done, date: when, note: trimmed}`.
4. Clear `snoozedUntil`.

Backdating an *older* dose than the latest one doesn't move the schedule back, because the latest event wins.

### Snooze (always 15 min in the UI): `snooze(item, minutes)`
- Not allowed for as-needed items (no-op).
- `snoozedUntil = max(nextDue, now) + minutes`. An overdue item is snoozed **from now**. Snoozing again **stacks**, because `nextDue` already includes the earlier snooze.

### Skip: `skip(item)`
- Not allowed for as-needed items (returns nothing).
- Clear the snooze. Then, keeping the rhythm:
  ```
  slot = nextDue(item)
  while followingSlot(slot) <= now: slot = followingSlot(slot)
  add event {kind: skipped, date: slot}
  ```
  So the next due becomes the first slot after now.
  - Interval item due 1 AM, every 3 h, skipped at 8 AM → skip recorded at 7 AM, next due 10 AM.
  - Daily 9 AM vitamin missed since 2 days ago, skipped at noon → next is 9 AM tomorrow.

### Edit a log entry: `updateEvent(id, date, note)`
A done entry's date is clamped to ≤ now; a skipped entry can be any date. The note is trimmed. The schedule recalculates automatically.

### Delete a log entry
Remove it. The schedule recalculates from whatever is now the latest.

### Undo
- Before any undoable change, the app keeps a **full copy of the previous state**. Undo puts it back.
- There is one level of undo, and only for the last action.
- It expires when the 5-second toast disappears. It is also lost if the data changes from outside (widget, Watch, Siri).
- Undoable: Done, Snooze, Skip, delete entry, delete item, vaccine given / visit given, delete vaccine.
- Not undoable: add item, edit item, edit entry.

## 6. Adding and editing items

**Validation** (`validate`):

| Rule | Error text |
|---|---|
| Name not blank (after trimming) | "Please enter a name." |
| Interval / gap between 30 min and 7 days | "Choose a time between 30 minutes and 7 days." |
| Set times: at least 1 time, each 0–1439 | "Add at least one time of day." |
| Name unique (case-insensitive, trimmed, ignoring itself) | "\"{name}\" is already in your care plan. Edit the existing one instead." |

On save, the name is trimmed and times are de-duplicated and sorted.

**First due on add** (from the editor's *Starts* control, Interval only):

| Starts | Result |
|---|---|
| Due now | `firstDue = now` |
| Already done | `firstDue = now`, and a Done is logged at the chosen past time |
| Due later | `firstDue = chosen future time` |

Set times and As needed always use `firstDue = now`, so a set-times item is due at the first slot from now.

**From onboarding:** each template is an Interval item with `firstDue = now + interval`.

**On edit:**
- `snoozedUntil` is cleared.
- If nothing has been logged yet:
  - Interval items take the new Starts choice.
  - Set-times items reset `firstDue` to now.
- Changing the interval or times takes effect straight away, recalculated from the last log.

**Course end:** "Last day" = D → `endDate = start of (D + 1 day)`. Presets "N days" set the last day to today + N − 1.

**Delete item:** removes the item **and all its events**.

## 7. History timeline for a day `timeline(day)`

1. All events on that day (local midnight to midnight) → **done** / **skipped** entries.
2. **Only if the day is today**, for each scheduled item:
   - If `nextDue ≤ now`, add one **overdue** entry at the due time.
   - Otherwise, add **planned** entries starting at `nextDue`, stepping with `followingSlot`, while still today, before `endDate`, and at most **12** per item.
3. Sort by time (ties by name).

**Past days never show invented "missed" slots**, only what was logged.

## 8. Text formatting (`CareFormat`)

| Function | Examples |
|---|---|
| interval | 30 → "Every 30 min" · 60 → "Every hour" · 90 → "Every 1h 30m" · 180 → "Every 3 hours" · 1440 → "Once a day" · 2880 → "Every 2 days" |
| schedule line | "Every 3 hours" · "Daily at 8:00 AM & 8:00 PM" (≤ 2 times) · "3× a day" · "As needed · 6h apart". Plus " · until 23 Oct" if it's a course |
| duration | "<1 min" · "42 min" · "1h 10m" · "3h" · "2d 3h" · "2d" (minutes rounded **up**) |
| relative | "due now" (within ±1 min) · "in 1h 10m" · "12 min late" |
| hero countdown | "Due now" · "in 1h 10m" · "12 min late" |

`ageDescription` ("6 weeks old", "1 year 2 months old") exists in the engine but is **not shown** in the UI (it was decided against). It stays covered by tests.

## 9. Things that are deliberately *not* done

- A missed scheduled item stays **overdue** until it is logged, skipped or snoozed. The app doesn't auto-skip it or roll it forward. See the known gap in [12](12-decisions-and-open-issues.md) about reminders after a miss.
- No partial doses, no amounts or volume tracking (feed ml, diaper type). These are ideas in the backlog.
