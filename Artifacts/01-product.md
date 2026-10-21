# 01 · Product

## Who it's for

New parents, mainly **new moms**, often tired and using the phone one-handed at 3 AM. The whole design follows from that: one big Done button, calm pastel colors, no clutter, and no sign-up.

**One baby per install.** Multi-baby was considered and rejected (see [12](12-decisions-and-open-issues.md)).

## The core loop

```
Set up a care plan  →  Get a reminder when something is due  →  Tap Done
        ↑                                                          │
        └──────── next due time is recalculated from the log ──────┘
```

1. **Care plan:** a list of *items* (Feed, Diaper change, Vitamin D3, an antibiotic course…). Each item repeats in one of three ways:
   - **Interval:** every X hours, counted from the last time it was done
   - **Set times:** fixed clock times every day, e.g. 8 AM and 8 PM
   - **As needed:** no reminders, only a minimum gap between doses (fever medicine)
2. **Reminder:** a local notification at the due time, with **Done** and **Snooze 15 min** buttons.
3. **Log:** tap Done (now or at an earlier time, with an optional note). The next due time is calculated from the log. Nothing is "stored" as a due time.
4. **History:** a per-day timeline of what was done, skipped, overdue and planned, shareable with the doctor.

## Feature list

**Onboarding**
- Welcome → baby (name, optional birth date, optional photo, "I'm Vedika's Mom/Dad/…") → pick starter items → allow notifications.
- If the app was deleted and reinstalled, the welcome screen offers **Restore** or **Start fresh**.

**Today tab**
- Header: avatar, greeting ("Good morning,"), and the caregiver title ("Vedika's Dad").
- Vaccination banner from 7 days before a visit is due.
- **Next up** hero card: countdown ring, big Done, Snooze, and "Done earlier? Pick the time".
- **Later** list of all other scheduled items, by due time.
- **As needed** list: "OK to give" or "Wait until 5:06 PM".
- Swipe right = Done. Swipe left = Skip / Snooze. Long-press = all options.
- An Undo toast after each action, shown for 5 seconds.

**History tab**
- A strip of the last 60 days plus a calendar jump.
- Day summary ("7 done · 1 skipped", "Feed ×6").
- Timeline: done, skipped, overdue, planned. Tap to edit the time or note, swipe to delete.
- Share the day as text or as an image.

**Care Plan tab**
- Items grouped as *Medicines & supplements* and *Care activities*, plus a **Finished** section for ended courses.
- Add or edit: quick-pick templates, any custom name, 24 icons, the three repeat modes, the start time, course length, dosage, notes, and reminders on/off.
- An entry point to **Vaccinations**.

**Vaccinations**
- Built from the India (IAP) schedule and the birth date, or "My own list".
- Next-visit card, visits with per-dose checkboxes, editable dates and notes.
- Reminders 3 days before each visit and on the day, at 9 AM.

**Outside the app**
- Notifications with Done/Snooze. Medicines repeat at +10 and +20 min if not done. Early heads-up 5 min before by default.
- Home Screen widgets (small, medium) with the baby photo and a Done button. Lock Screen widgets.
- Apple Watch app: next up, Done, Snooze.
- Siri: "Log feed in Baby Care Clock", "What's next in Baby Care Clock".

**Settings**
- Baby profile and photo. Reminder options. Theme. In-app sounds (Daytime only / Always / Off).
- Export the data as JSON. Delete all data. Privacy and medical disclaimer.

## Positioning (from the App Store copy)

- Name: **Baby Care Clock**. Subtitle: *Feeds, Naps & Vitamin Timer*.
- Category: Health & Fitness, not Medical (Medical apps get stricter review).
- Free for now. No ads (decided).
- The full listing text is in `../AppStore/LISTING.md`. The privacy policy and support page are in `../AppStore/`.

## Medical stance

The app is a **reminder tool, not medical advice**. This line appears in onboarding, the medicine editor, Vaccinations and Privacy. Keep it on Android.
