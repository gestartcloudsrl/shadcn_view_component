# Event calendar: the week as rows

**Status:** agreed, 2026-11-10. Feeds an implementation plan; not itself a plan.

**The question:** the week has one view, the timeline — seven `Hours` rows over
one `window`. The month already has a second way to lay a day out, the workload
reading's rows: a day per row, its chips in a strip ordered by time, no clock
axis. Gestart wants the same choice in the week: **rows or timeline**, picked
from the same panel.

## Why

The timeline answers *when*: Tuesday at ten sits above Thursday at ten. The rows
answer *what is on, and whose*: a row has room for the clock, the client and the
crew of every job, in order, without a lane packing deciding the height. Both
questions get asked of a week, so both views belong to it.

## What a person sees

A wireframe of all three is in
`.superpowers/brainstorm/58313-1794303577/content/week-rows.html` (local, not
committed).

### The panel

The panel asks three things, in order, as it already does for the month:

| period | view | its question |
|---|---|---|
| Monthly | Grid · Rows · Timeline | group by (grid, rows) · chips or bars (timeline) |
| **Weekly** | **Rows · Timeline** | **group by (rows)** · chips or bars (timeline) |
| Daily | — | timeline only · timeline and list |

So for a week the view question is drawn — today it is not, because the week
had one view — and it offers **Rows** and **Timeline** only.

### Weekly · Rows

- **Seven rows, Monday to Sunday** (or whatever `week_starts_on` says), one per
  day of the week that holds `selected`, exactly the week the timeline shows.
- **Each row is the month's rows-arrangement row**: the date column on the left
  (weekday, day, count), then the day's chips in a strip that scrolls sideways.
- **Group by event or by assignee**, as in the month. By event, a chip is one job
  — clock, client, crew, the done and attachment flags, the host colour. By
  assignee, a chip is one operator and how many jobs they have that day.
- **The selected day's list stays under the week**, with the rows that open an
  event (`url:` and `attributes:`), exactly as under the timeline. The user
  asked for this explicitly, even though a chip already shows most of what a
  row in the list says.

### Weekly · Timeline

Unchanged.

## Decisions

Taken in the conversation:

- The week offers **Rows** and **Timeline**; rows offer **by event** and **by
  assignee**.
- The rows look like the month's rows.
- The day list under the week stays in both views.

Proposed by Claude and accepted without change:

- **The default does not move.** A host passing `reading: :weekly` today keeps
  getting the timeline. Rows are asked for explicitly. The gem is published;
  changing what an existing call draws is a breaking change.
- **No Grid for the week.** Seven narrow columns are what the rows were built to
  avoid, and nobody asked for it.
- **Same rules as the rest of the week.** Drawn by the server, `‹ ›` step a week
  and are links, `movable:` does not reach it.
- **Chips stay decoration inside the day's target.** Clicking a day row selects
  it (or follows `day_url:`); the event opens from the list underneath. Same
  rule as the event-content design (2026-11-09).
- **Same vocabulary for `view_url:`.** It is handed `:rows` and `:hours` from the
  week's view question, as from the month's, and `:weekly` from the period
  question. No new words. A host already keeps the period in its own state to
  tell the month's `:rows` from the week's.

## Left to the builder

- **How a host asks for it.** The natural reading is
  `reading: :weekly, arrangement: :rows` (plus `group:`), reusing the keyword the
  workload reading already owns, with `:auto` meaning the timeline for a week.
  A different spelling is fine if it keeps `reading: :weekly` alone meaning the
  timeline and adds no new `view_url:` words.
- **The class shape.** The rows are the workload reading's; the week's title,
  nav step and day selection are `Weekly`'s. Whether that is a subclass of
  `Workload::Component` that borrows the week's parts (a shared module with
  `Weekly`), or something else, is the builder's call. `Weekly < Hours` stays.
- **Rows at every width.** In the week the rows are forced (as
  `arrangement: :rows` forces them in the month) — there is no grid to fall back
  to above `lg`.
- **What the workload row brings along.** The heat ramp on the day, the `CAP`
  of three chips with "+N", and the *Show all* toggle are the month row's. Keep
  them as they are unless keeping one turns out to be wrong for seven rows —
  and if so, say which and why in the plan.
- **The heat ramp's scale** *(Claude's call)*: if the ramp is kept, it stays
  scaled against the month the week sits in, not rescaled to the week, so a
  day reads the same in both periods.
- **A week crossing two months** *(Claude's call)*: reuse `Weekly#week` and its
  fallback as they are, and the outside-day styling the grid already has.
- **Docs.** The feature doc's *The period, the week and the day* and *One
  options panel* sections, `todo.md`, and a Lookbook preview of the week in rows
  (both groupings reachable), so the snapshot and accessibility specs cover it.

## Not in this design

- A seven-column grid for the week.
- Rows for the day (`Daily` keeps its own halves).
- Making the rows' chips links or movable.
