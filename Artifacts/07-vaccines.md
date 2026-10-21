# 07 · Vaccinations

Source: `Shared/Vaccines.swift`, `ChildCareClock/VaccinesView.swift`.

## Built-in schedule: India (IAP)

Based on the Indian Academy of Pediatrics immunisation schedule, birth to 6 years. It is the only built-in schedule so far (`VaccineSchedule.all = [india]`), and the code is ready for more countries.

| Visit | Age used for the due date | Vaccines |
|---|---|---|
| At birth | 0 | BCG, OPV 0, Hepatitis B 1 |
| 6 weeks | 6 weeks | DTwP/DTaP 1, IPV 1, Hib 1, Hepatitis B 2, Rotavirus 1, PCV 1 |
| 10 weeks | 10 weeks | DTwP/DTaP 2, IPV 2, Hib 2, Hepatitis B 3, Rotavirus 2, PCV 2 |
| 14 weeks | 14 weeks | DTwP/DTaP 3, IPV 3, Hib 3, Hepatitis B 4, Rotavirus 3, PCV 3 |
| 6 months | 6 months | Influenza 1 |
| 7 months | 7 months | Influenza 2 |
| 9 months | 9 months | MMR 1, Typhoid conjugate (TCV) |
| 12 months | 12 months | Hepatitis A 1 |
| 15 months | 15 months | MMR 2, Varicella 1, PCV booster |
| 16–18 months | 16 months | DTwP/DTaP booster 1, Hib booster, IPV booster |
| 18–19 months | 18 months | Hepatitis A 2, Varicella 2 |
| 4–6 years | 48 months | DTwP/DTaP booster 2, Polio booster, MMR 3 |

Rajath still needs to check this table against the baby's real vaccination card (open to-do).

## Rules

- **Due date** = start of the birth day + `months` (calendar months) + `weeks × 7` days. So 6 weeks = birth + 42 days, and 9 months follows the calendar (1 Sep → 1 Jun).
- **Visit** = doses sharing the same `visit` label and due day. Doses in a visit are sorted by name, and visits are sorted by date.
- **Visit status** (compared by calendar day):
  - **given:** every dose has a `givenDate`
  - **overdue:** the due day is before today
  - **due soon:** within **7 days** (including today)
  - **upcoming:** later than that
- **Due text:** "Due today" · "Due tomorrow" · "In 3 days" · "1 day overdue" · "2 days overdue".
- **Next visit** = the first visit by date that still has doses to give.

## Setup choices

1. **India (IAP)** + birth date + "Mark past vaccines as given" (default **on**). Every dose due before today gets `givenDate = dueDate`, so the list starts at the next visit. Turning the toggle off makes missed ones show as overdue.
2. **My own list:** creates a single "First vaccine" dose on the birth date for the user to edit and add to.

If the baby had no birth date, the one chosen here is saved to the profile.

## Changing things later

| Action | Effect |
|---|---|
| Tick or un-tick a dose | Sets or clears `givenDate` (today). Undo is available |
| "All given today" (next visit card, when due soon or overdue) | Marks all remaining doses in that visit as given today |
| Edit a dose | Name, due date, given/on date, note. **Changing the due date sets `dueDateEdited = true`** |
| Add a vaccine | Name and due date. Gets visit "Added by you" and `dueDateEdited = true` |
| Delete a dose | Removed. Undo is available |
| Start over | Clears the whole list and shows the setup screen again |
| **Birth date changed in Settings** | Recalculates due dates for doses that are **not given and not hand-edited**, using their stored age |

## Where it shows up

- The **Care Plan** first row ("Vaccinations"), which opens the full page.
- The **Today** banner, only when the next visit is due soon or overdue.
- **Notifications** 3 days before and on the day, at 9 AM (see [06](06-notifications.md)).
- Vaccines are **not** sent to the Watch.
