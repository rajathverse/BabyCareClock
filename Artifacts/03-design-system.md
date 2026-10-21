# 03 · Design system

Source: `Shared/Theme.swift`, `ChildCareClock/Components.swift`, `ChildCareClock/SoundManager.swift`.

**Mood:** soft, calm, pastel. Translucent "glass" cards on a gentle gradient. Full light and dark mode (the user picks System, Light or Dark in Settings).

## Colors

Every color has a light and a dark value. Pastels are used for fills and rings; the deeper "text" shades keep labels readable.

| Token | Light | Dark | Used for |
|---|---|---|---|
| `primary` | `#8B7CF6` | `#B3A8FF` | Buttons, selected chips, rings (upcoming), tint |
| `primaryDeep` | `#6A58E0` | `#CFC7FF` | Links, soft-button text, upcoming countdown text |
| `onPrimary` | `#FFFFFF` | `#1C1828` | Text on primary buttons and chips |
| `text` | `#3B3450` | `#ECE8F4` | Main text |
| `secondaryText` | `#6F6786` | `#A59DB8` | Captions, subtitles, section headers |
| `medicine` | `#B9A6F7` | `#8F7FD9` | Medicine badge fill (at 28 % opacity) |
| `medicineDeep` | `#6F5AD9` | `#D3C9FF` | Medicine icon color |
| `care` | `#7CCFC3` | `#4FA89C` | Care badge fill (at 28 % opacity) |
| `careDeep` | `#2C8A7D` | `#9BE3D8` | Care icon color |
| `done` | `#8FD9B0` | `#5DB585` | Done swipe, timeline dot, vaccine check |
| `doneText` | `#2F7D52` | `#9FE3BD` | "OK to give", toast icon, Done pill |
| `soon` | `#F5C77E` | `#D9A85A` | Due-soon ring, Snooze swipe, warning box |
| `soonText` | `#99661A` | `#F3CD8C` | "Wait until", due-soon text |
| `overdue` | `#F2948A` | `#E07A70` | Overdue ring, card outline, dot |
| `overdueText` | `#B84A40` | `#F5A79F` | Overdue text, destructive hints |
| `backgroundTop` | `#F8F5FF` | `#1C1828` | Gradient, top |
| `backgroundMiddle` | `#FFF4EF` | `#181524` | Gradient, middle |
| `backgroundBottom` | `#F1FAF6` | `#141220` | Gradient, bottom |
| `blobLavender` | `#E4DBFF` | `#3A2F63` | Background blob |
| `blobPeach` | `#FFDCCD` | `#3B2440` | Background blob |
| `blobMint` | `#D3F2E6` | `#173A37` | Background blob |

**Status → color:** upcoming = `primary`, due soon = `soon`, overdue = `overdue`. The pill and ring backgrounds use the same color at 18 % opacity.

**Category → color:** medicine = lavender, care = mint.

The Watch is always dark and uses its own simplified palette (`ChildCareClockWatch/WatchContentView.swift`).

## Background

A vertical gradient (top → middle → bottom) with three big blurred circles at 80 % opacity:
- lavender: 90 % of screen width, blur 70, offset to the top-left
- peach: 75 %, blur 80, right side at 25 % height
- mint: 80 %, blur 80, left side at 70 % height

It runs edge to edge, behind the status bar. Android: a `Box` with a `Brush.verticalGradient` and three `Modifier.blur` circles (API 31+; use a pre-rendered image on older devices).

## Glass panel (cards)

- Rounded rectangle, **22 dp** radius by default (rows 20, hero 26, toast 18, small 16), continuous corners.
- Fill: iOS "ultra thin material", a translucent blur. Android: surface color at about 60–70 % alpha.
- Hairline border, 0.7 dp: white at 55 % (light) or 8 % (dark).
- Shadow in light mode only: `primaryDeep` at 7 %, radius 14, y-offset 6.

## Type

- System font with the **rounded** design everywhere (SF Pro Rounded). Android: Nunito or Quicksand from Google Fonts are close matches.
- Uses the iOS text styles; Dynamic Type is supported.

| Use | Style |
|---|---|
| Hero item name | title2, bold |
| Hero countdown | title, bold, monospaced digits |
| Header name | title2, bold |
| Row title | headline |
| Row subtitle | subheadline, secondaryText |
| Section headers | caption, bold, UPPERCASE, letter-spacing 1.1–1.2 |
| Onboarding titles | title, bold / largeTitle, bold |

## Components

| Component | Spec |
|---|---|
| **Primary button** | Full width, min height 52, radius 16, `primary` gradient fill, `onPrimary` bold text. Pressed: 85 % opacity, 98 % scale |
| **Soft button** | Same size, `primary` at 14 % (22 % pressed), `primaryDeep` text |
| **Choice chip** | Capsule, min height 40, 14 horizontal padding, optional icon. Selected: `primary` fill and `onPrimary` text. Unselected: `primary` at 10 % |
| **Symbol badge** | Icon in a circle; size 28–52 (rows 44). Category color at 28 % fill, deep tint icon at 45 % of the size |
| **Countdown ring** | Track at 18 % of the status color. The arc starts at 12 o'clock, has round caps, and shows the remaining fraction (min 2 %). Overdue: a full ring. Line width 11 (hero), 4 (rows) |
| **Baby avatar** | A circular photo, or the initial on a medicine→care gradient (a smiley if there's no name). White 2 dp border and a soft shadow |
| **Toast** | Glass panel 18 radius. Icon in `doneText`, message, optional "Undo" capsule button. Floats 78 dp above the bottom |
| **Empty state card** | 72 dp icon circle, title3 bold title, message, optional primary button |
| **Flow layout** | Chips wrap onto new lines (Android: `FlowRow`) |

## App mark

Drawn in code (`AppMark` in `OnboardingView.swift`): a rounded square with a lavender → peach gradient, a white clock face with 12 ticks, two purple hands, and a small coral heart in the middle. The App Store icon is a separate asset in `../ChildCareClock/Assets.xcassets`.

## Icons: SF Symbols → Material Symbols

The app uses Apple's SF Symbols. Suggested Material Symbols (Rounded, filled) for Android:

| SF Symbol | Used for | Material Symbol |
|---|---|---|
| `drop.fill` | Feed | `water_drop` |
| `waterbottle.fill` | bottle | `baby_changing_station` / `local_drink` |
| `sparkles` | Diaper change | `auto_awesome` |
| `moon.zzz.fill` | Nap | `bedtime` |
| `figure.and.child.holdinghands` | Tummy time | `family_restroom` |
| `heart.fill` | Kangaroo care, care default | `favorite` |
| `bathtub.fill` | Bath | `bathtub` |
| `teddybear.fill` | Play time | `toys` |
| `stroller.fill` | Walk outside | `stroller` |
| `sun.max.fill` | Vitamin D3 | `light_mode` |
| `eyedropper.halffull` | Iron drops | `colorize` |
| `cross.vial.fill` | Calcium syrup | `science` |
| `pills.fill` / `pill.fill` | medicine default | `medication` / `pill` |
| `leaf.fill` | Probiotic | `eco` |
| `syringe.fill` | Vaccines | `vaccines` |
| `thermometer.medium` | fever | `thermometer` |
| `bandage.fill` | | `healing` |
| `hands.and.sparkles.fill` | | `clean_hands` |
| `music.note` | | `music_note` |
| `book.fill` | | `menu_book` |
| `fork.knife` | | `restaurant` |
| `cup.and.saucer.fill` | | `coffee` |
| `star.fill` | | `star` |
| `checkmark` / `checkmark.circle.fill` | Done | `check` / `check_circle` |
| `clock.arrow.circlepath` | Snooze, History tab | `snooze` / `history` |
| `forward.end` | Skip | `skip_next` |
| `sun.horizon.fill` | Today tab | `wb_twilight` |
| `list.bullet.clipboard` | Care Plan tab | `assignment` |
| `gearshape.fill` | Settings | `settings` |
| `bell.badge.fill` / `bell.slash.fill` | reminders | `notifications_active` / `notifications_off` |

**Store icon names, not images:** the saved data contains the SF Symbol name (e.g. `"drop.fill"`). Keep the same strings on Android and map them to Material icons in code, so exported files stay compatible across platforms.

## Sounds and haptics

`ChildCareClock/Sounds/` holds three short, soft WAV chimes made for this app: `done.wav`, `snooze.wav`, `tap.wav`. Reuse the files as they are.

| Event | Chime | Haptic |
|---|---|---|
| Done (and vaccine given) | `done` | success notification haptic |
| Snooze | `snooze` | soft impact |
| Skip, chip tap, undo | `tap` | soft impact |
| Validation error | none | warning haptic |

- The chimes follow the **Sounds** setting. *Daytime only* (default) is silent from 21:00 to 06:59. *Always* plays at any hour. *Off* never plays.
- **Haptics always play.**
- Chimes respect the silent switch and mix with music instead of stopping it (Android: `USAGE_ASSISTANCE_SONIFICATION`, no audio focus request).
- Notification sounds are separate. They always use the system default.

## Motion

- Spring and "snappy" animations on state changes. Onboarding steps slide in from the right.
- Countdown numbers roll with a numeric text transition.
- Rings animate smoothly over 0.6 s.

## Accessibility

- Every row is announced as one combined element, e.g. "Feed, in 1 hour 10 minutes".
- Icons are hidden from VoiceOver. Buttons have labels ("Settings", "Add to care plan", "Mark BCG as given").
- Tap targets are at least 44 pt.
