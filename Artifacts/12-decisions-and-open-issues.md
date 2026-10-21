# 12 · Decisions, open issues, ideas

## Decided (keep on Android unless we agree otherwise)

- **Any baby, aimed at new moms, one baby per install.**
- **Header:** a time-of-day greeting ("Good morning / afternoon / evening", and "Hello" from 10 PM to 5 AM, never "night owl") above the caregiver title "Vedika's Dad". **No age line and no "done today" line.**
- **Reminders:**
  - A due-time notification with Done / Snooze 15 (shown on press-and-hold).
  - Medicines repeat at +10 and +20 min if not done.
  - Early heads-up 5 min before by default.
  - "Due soon" 15 min before.
  - **No photo in notifications.**
- **In-app chimes:** own generated WAVs. Sounds = *Daytime only* (default, silent 9 PM–7 AM) / Always / Off. Haptics always play.
- **Data survives a reinstall** (Keychain copy). The welcome screen offers Restore / Start fresh.
- **Repeat modes:** Interval · Set times · **As needed**. As needed stays as a safety feature for fever medicine (minimum gap, no reminders).
- **Privacy first:** no account, no server, no ads, no analytics.
- **Medical disclaimer** on onboarding, the medicine editor, Vaccinations and Privacy.
- **Vaccines:** India (IAP) schedule from the birth date, every date editable.
- **Store pages:** privacy and support pages at `https://www.rajathverse.com/babycareclock/` (privacy at `/privacy`). Contact rajathverse@gmail.com.
- **Name:** "Baby Care Clock" (formerly "Child Care Clock"). Internal names and the bundle id stay `ChildCareClock`.

## Rejected, please don't re-propose without discussing

| Idea | Status |
|---|---|
| Live Activity / Dynamic Island / persistent Lock Screen card (Android: a persistent ongoing notification) | Rejected |
| AlarmKit-style full alarms | Rejected |
| Baby photo as the app icon, or in notifications | Rejected |
| An extra "+" button on Today | Rejected |
| Keep screen awake | Rejected |
| Multiple babies | Rejected |
| Emoji icons | Rejected (use proper icon sets) |
| Ads | Rejected |

## Known gaps and open issues

1. **Reminders stop after a missed one.**
   - Only the *next* due time of each item gets a notification ([06](06-notifications.md)). If a reminder is dismissed without tapping Done and the app isn't opened, the item stays overdue and **no later reminders are scheduled**. For example, a vitamin at 8 AM, 2 PM and 8 PM won't remind at 2 PM or 8 PM if the 8 AM one was swiped away.
   - Rajath is happy with the current behaviour on iOS for now.
   - On Android, either keep the same behaviour, or schedule the next 2–3 occurrences per item. Worth a decision together.
2. **Apple Watch app not tested** on a device or the simulator yet.
3. **Vaccine table not yet checked** against a real vaccination card.
4. **"Baby Care Clock" name availability** on the App Store is not confirmed. Check Play Store too.
5. **The paid Apple Developer account** is needed before App Store release. It also re-enables Time Sensitive notifications (removed because the free account blocks them).
6. **No import** for the exported JSON.
7. Leftover code that only ends Live Activities from old test builds (`LiveActivityManager.swift`, `Shared/CareLiveActivity.swift`). It can be deleted later. Ignore it for Android.
8. The root `README.md` says the engine test has 82 checks. It now has **106**.
9. Only English. No localisation yet.

## Business notes (discussed, not built)

- Suggested model: **freemium**, with ₹299/year (7-day free trial) plus a lifetime option, and Family Sharing.
- Against ads.

## Idea backlog (not chosen yet)

- **Parent sync:** two parents sharing one baby. On iOS this needs the paid account (iCloud). This is the biggest one, and the Android version should be designed with it in mind.
- iCloud / cloud backup.
- **Feed details:** side (L/R), ml, duration; diaper type (wet/dirty).
- Growth charts (weight, height, head).
- Doctor report as a PDF (multi-day).
- Medicine stock ("3 days left, refill").
- Sleep timer (start/stop).
- Indian languages (Hindi, Kannada, Tamil, Telugu…).
- Import of the exported file (lets users move iPhone ↔ Android).

## Cofounder feedback

Add ideas and improvements below, or open GitHub issues. One line each is enough.

| # | Area | Idea / problem | Why | Priority |
|---|---|---|---|---|
| 1 | | | | |
