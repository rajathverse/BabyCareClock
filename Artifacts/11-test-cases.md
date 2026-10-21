# 11 · Engine test cases

Source: `Verification/EngineSmokeTest.swift`. On a Mac, `./verify_engine.sh` prints **"All 106 checks passed."** (checked on 2026-10-21).

Port these to JUnit. If the Kotlin engine passes all of them, it behaves like the iOS app.

**Test setup:** Gregorian calendar, time zone **America/New_York** (chosen because it has DST). Dates are written `Oct 17 09:00` = 2026-10-17 9:00 AM local. "+3h" items have `intervalMinutes = 180`.

## A. First due time
| Given | Expect |
|---|---|
| Feed every 3h, `firstDue` Oct 17 09:00, no log | nextDue = Oct 17 09:00 |
| Vitamin daily, `firstDue` Oct 17 21:00 | nextDue = Oct 17 21:00 |
| Both of the above | schedule order = [Feed, Vitamin D3] |

## B. Done, backdating, the latest log wins (now = Oct 17 12:00, Feed 3h)
| Given | Expect |
|---|---|
| Done at 11:30 | nextDue 14:30 |
| Also log an older Done at 08:00 | still 14:30 (the older log doesn't override) |
| Done at 13:00 (future) | saved as 12:00; nextDue 15:00 |
| Delete that 12:00 entry | back to 14:30 |
| Edit the latest entry to 11:00 with note " Left side " | nextDue 14:00; note saved as "Left side" |
| Change the interval to 2h | nextDue 13:00 |

## C. Snooze and skip (now = Oct 17 10:00, Diaper 3h, firstDue 09:00)
| Given | Expect |
|---|---|
| Snooze 15 (overdue) | nextDue 10:15 (from now) |
| Snooze 15 again | 10:30 (stacks) |
| Done at 10:00 | `snoozedUntil` cleared; nextDue 13:00 |
| Skip (upcoming) | nextDue 16:00 |
| Done at 10:05 (now 10:05) | the skip event is removed; nextDue 13:05 |
| Iron every 3h, firstDue 01:00, skip at 08:00 | nextDue 10:00 |

## D. Status and ring (now = 12:00, warning 15 min)
| Due | Expect |
|---|---|
| 11:59:59 | overdue |
| 12:00 exactly | overdue |
| 12:15 | due soon |
| 12:16 | upcoming |
| Feed 3h due 13:30 | ring fraction 0.5 |
| due 11:00 | fraction 0 |

## E. DST (interval)
| Given | Expect |
|---|---|
| Feed 3h done Oct 31 23:00 (US clocks fall back Nov 1 02:00) | nextDue exactly 3 real hours later, shown as **1 AM** |

## F. Timeline (now = Oct 17 12:00)
Feed 3h (firstDue 12:00), Bath daily (firstDue 09:00). Feed done Oct 17 11:00 "Left" and Oct 16 22:00.
| Given | Expect |
|---|---|
| Today | exactly 1 done entry (note "Left") |
| Today | Bath shown as **overdue** |
| Today | planned Feeds at 14:00, 17:00, 20:00, 23:00 |
| Today | entries sorted by time |
| Oct 16 | only the 22:00 done entry, no invented slots |
| Oct 10 | empty |
| Delete the Feed item | all its events are gone |

## G. Validation
| Given | Expect |
|---|---|
| Add "  feed " when "Feed" exists | error duplicateName("feed") |
| Name "   " | error missingName |
| Interval 15 min | error intervalOutOfRange |
| Update Feed (notes only) | OK (its own name isn't a duplicate) |

## H. Formatting and age (now = Oct 17 12:00)
| Input | Expect |
|---|---|
| interval 180 / 30 / 90 / 60 / 1440 / 2880 | "Every 3 hours" / "Every 30 min" / "Every 1h 30m" / "Every hour" / "Once a day" / "Every 2 days" |
| duration 70 min / 42 min / 30 s | "1h 10m" / "42 min" / "<1 min" |
| relative: due 12 min ago | "12 min late" |
| relative: due in 20 s | "due now" |
| born Oct 17 03:00 | "Born today" |
| born Oct 12 | "5 days old" |
| born Sep 5 | "6 weeks old" |
| born May 10 2026 | "5 months old" |
| born Aug 1 2025 | "1 year 2 months old" |

## I. Set times
Antibiotic times `[1200, 480]`, firstDue Oct 17 14:00.
| Given | Expect |
|---|---|
| Saved | times stored as [480, 1200] |
| No log | nextDue Oct 17 20:00 |
| Done 20:20 (20 min late) | nextDue Oct 18 08:00 |
| Done Oct 18 07:30 (30 min early) | nextDue Oct 18 20:00 |
| Vitamin `[540]`, firstDue Oct 15 08:00, skip at Oct 17 12:00 | nextDue Oct 18 09:00 |
| Drops `[480, 840, 1200]`, firstDue Oct 17 09:00, timeline at 09:00 | planned 14:00, 20:00 |
| Same, due 14:00, now 11:00 | ring fraction 0.5 (gap since the 08:00 slot) |
| Iron `[540]`, firstDue Oct 31 12:00 | nextDue Nov 1 **09:00** (wall clock, across DST) |
| Times `[]` | error missingTimes |

## J. As needed (now = Oct 17 12:00, Fever medicine gap 6h)
| Given | Expect |
|---|---|
| Added | not in the scheduled list; `sendsReminders` false |
| Never given | lastGiven null, okAfter null ("OK to give") |
| Given 10:00 | lastGiven 10:00, okAfter 16:00 |
| At 16:01 | okAfter null |
| Skip | not allowed (returns null) |
| Snooze | no effect (`snoozedUntil` stays null) |
| Timeline today | only the one done entry |

## K. Course length
Antibiotic `[480, 1200]`, firstDue Oct 17 07:00, endDate Oct 19 00:00 (last day Oct 18).
| Given | Expect |
|---|---|
| At 07:00 | in the scheduled list |
| Done 17th 08:00, 20:00, 18th 08:00 | not finished yet |
| Timeline Oct 18 at 09:00 | 1 planned slot (20:00), nothing after the end |
| Done 18th 20:00 | finished; leaves Today; listed under Finished |

## L. Save / load
| Given | Expect |
|---|---|
| Items with times + endDate and as-needed | encode → decode gives an identical state |
| Old minimal JSON (see below) | loads with schemaVersion 1, role "", no vaccines, item kind care, icon `heart.fill`, reminders on, interval mode, no end; event kind done, empty note |
| That state saved and loaded again | the saved bytes are identical (whole-second dates) |

Old minimal file:
```json
{"baby":{"name":"Baby"},"items":[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"Feed","intervalMinutes":180}],
 "events":[{"id":"7F9619FF-8B86-D011-B42D-00C04FC964FF","itemID":"6F9619FF-8B86-D011-B42D-00C04FC964FF","date":"2026-10-17T10:00:00Z"}]}
```

## M. Caregiver title
| Given | Expect |
|---|---|
| Vedika + Mom | "Vedika's Mom" |
| Vedika + " Dad " | "Vedika's Dad" |
| Dhruvs + Mom | "Dhruvs' Mom" |
| Vedika, no role | null |

## N. Vaccines (birth Sep 1 2026 15:00, now Oct 17 2026 12:00, IAP, mark past = on)
| Given | Expect |
|---|---|
| First visit | "At birth" on Sep 1 00:00 |
| Second visit | "6 weeks" on Oct 13 |
| "9 months" | Jun 1 2027 |
| At birth and 6 weeks | marked given |
| Next visit | "10 weeks" with 6 doses, status upcoming (24 days away) |
| Status at Nov 5 / Oct 20 / Nov 12 | due soon / upcoming / overdue |
| Due text at Nov 10 / Nov 12 | "Due today" / "2 days overdue" |
| Mark 10 weeks given | next visit = "14 weeks" |
| Hand-edit a 14-week dose to Dec 20, then birth date → Sep 3 | edited dose stays Dec 20; the given 6-week dose stays Oct 13; MMR 1 moves to Jun 3 2027 |
| Add "  Meningococcal " | saved as "Meningococcal", visit "Added by you" |
| Mark past = off | next visit "At birth" |
| Encode → decode | same vaccine count |
