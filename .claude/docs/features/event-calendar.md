# Event calendar

*Ours. There is no shadcn event calendar to be 1:1 with.*

`vendor/shadcn/ui/calendar.tsx` is the day **picker** — `react-day-picker`, for
choosing a date. Nothing upstream shows what is *happening* on a day. The
reference this was built against is therefore FullCalendar's `dayGridMonth`,
which is the shape everyone already knows, and the constraint was shadcn's
visual language rather than shadcn's markup.

`reverse_parity_spec` lists every class it renders, one by one, for the same
reason the toaster's are listed: the components with no upstream must not also
be the ones nobody checks.

## What it is

**One component to a host, four to this directory.**
`EventCalendar::Component.new(reading:)` is the whole public surface — it hands
over to a subclass from `.new`, so nothing here names one and the root stays a
single element. Two plain objects beside them do the thinking, and one Stimulus
controller moves them.

It was one 1,592-line class until the measurements said otherwise; the seam and
the numbers that argued it are in
[architecture](../decisions/01-architecture.md#when-one-component-grows-a-second-reading).

```ruby
render Shadcn::EventCalendar::Component.new(
  month: Date.new(2026, 8, 1),
  selected: Date.new(2026, 8, 20),
  max_events: 3,
  events: Meeting.for(current_user).map do |meeting|
    { title: meeting.name, starts_at: meeting.begins_at, ends_at: meeting.ends_at,
      color: :blue, url: meeting_path(meeting) }
  end
)
```

`events:` takes plain hashes because that is what comes out of a `map` over a
host's own records, and a library cannot know what those records are called.
`Event.wrap` normalises each one; an already-built `Event` passes through.

## Options

The reference: every argument, its values and its default. *Why* each one is
shaped the way it is lives in the sections below. A value outside the list
falls back to the default rather than raising. The arguments that raise are
`movable: true` without an `id:` on every event, and a `preferences:` that is
not `:local` or `:host` or comes without its mode's URL (see
[a person's preferred view](#a-persons-preferred-view)).

### Every reading

| Argument | Default | |
|---|---|---|
| `month:` | today's month | the month shown |
| `selected:` | today if it is in the month, else the 1st | the day the agenda reads out |
| `events:` | `nil` | hashes or `Event`s, see [one event](#one-event) |
| `reading:` | `:auto` | which reading draws the month, see below |
| `max_events:` | `3` | bars per cell before "+2", clamped to 1–6 |
| `week_starts_on:` | the host's `Date.beginning_of_week` | a `Date#wday`, 0 is Sunday |
| `default_color:` | `:default` | the colour of events that name none |
| `month_url:` | `nil` | given a `Date`, that month's URL. Present, the nav is links and the server draws the month |
| `day_url:` | `nil` | given a `Date`, that day's URL. Present, a cell is a link and the server owns what a click shows |
| `day_attributes:` | `{}` | merged onto every day cell, e.g. `data: { turbo_frame: … }` |
| `agenda:` | `true` | `false` drops the built-in day list, for a host that shows the day elsewhere |
| `agenda_as:` | `:div` | the agenda's element; `:"turbo-frame"` makes it what a day link swaps |
| `agenda_attributes:` | `{}` | merged onto the agenda, e.g. its `id` |
| `view_url:` | `nil` | given `:monthly`, `:weekly`, `:daily`, `:grid`, `:rows` or `:hours`, that view's URL. Present, the options panel is links |
| `movable:` | `false` | events can be moved; needs an `id:` on each |
| `shapes:` | `[:chips, :bars]` | the shapes offered. One alone is drawn whatever `shape:` says, and the panel, its trigger and the preferences dialog stop mentioning shape at all. Every reading reads it, because the dialog on a month grid asks the shape for *Monthly · Timeline* |
| `counts:` | `true` | `false` hides the badge that counts a day's events (and, on the day by assignee, each person's). The badge is also what wears the heat ramp, so the ramp goes with it; the chips, the "+N" and *Show all* stay. Cast as Rails casts a boolean, so `"false"` from `params` is off. The readings without a badge (`:auto`) ignore it |
| `preferences:` | `nil` | `:local` or `:host`: the panel gets a *Preferences* item and the dialog it opens. Drawn by the readings with a panel only. `nil` and `false` are off, so `preferences: feature_on? && :host` works; any other value raises |
| `preferences_url:` | `nil` | `:local` only, and required there: given one complete set (`{ period:, view:, showing:, group:, shape:, max_chips: }`, the keys that apply), the URL that draws it. Where the set asks the chip limit it is also called with two numbers (23 and 45) to find where a typed one goes, so it must write `max_chips` into the URL once, as given, or leave it out; anything else raises `ArgumentError` at render time |
| `preferences_save_url:` | `nil` | `:host` only, and required there: where the dialog's form is sent, as `PATCH` |
| `restore:` | `false` | `:local` only: this request is the bare arrival, so go to the stored set if there is one |
| `**attributes` | | HTML on the root; `class` and `data-action` add to the gem's |

### `reading:`

| Value | What it draws |
|---|---|
| `:auto`, `:events` | the month as a grid, bars or marks by density |
| `:workload` | the month for field work: rows below `lg`, the grid above |
| `:hours` | the month as a timeline, a row of hours per day |
| `:weekly` | the week as a timeline; with `arrangement: :rows`, as rows |
| `:daily` | one day |

### Arguments only some readings take

Passed to a reading that does not take one, it lands on the root as
`data-event-calendar-*` and does nothing (`READING_KEYWORDS`).

| Argument | Readings | Values, default first |
|---|---|---|
| `group:` | workload, week as rows, day | `:events`, `:assignees` |
| `show_all:` | workload, week as rows | `false`, `true` (every chip instead of a cap and "+N") |
| `max_chips:` | workload, week as rows | `3`, any number from 1: the chips a cell shows before its "+N". A person's preference, passed back in by the host; the dialog's field takes 1 to 99 (`Preferences::MAX_CHIPS_RANGE`). *Show all* is still the toggle past it. No `max_chips_url:`, because no control on the toolbar changes it: the host's own `*_url:` lambdas carry it like the rest of its state |
| `arrangement:` | workload, week | `:auto`, `:rows` |
| `window:` | month and week timelines, day | `0..24`, any range of hours, e.g. `7..19` |
| `shape:` | month and week timelines, day | `:chips`, `:bars` |
| `showing:` | day | `:both`, `:axis`, `:agenda` |

`shapes:` is there because a host can know its people never want one shape.
Gestart has no use for bars and does not want them offered, so
`shapes: [:chips]` takes "Bars" off the menu and "Chips" off the trigger. A
question with one answer would still mention the other. The rule is the
panel's own, the one that keeps the shape off a day showing only its list: a
question is asked only where it has something to decide.

Each of `group:`, `show_all:`, `shape:` and `showing:` has a `*_url:`
partner (`group_url:`, `show_all_url:`, `shape_url:`, `showing_url:`), given
the wanted value and returning its URL. Present, that menu is links. Absent,
it dispatches the event below and the host decides.

### One event

| Key | |
|---|---|
| `title:`, `starts_at:` | required. A `Date` is all-day, a `Time` has a time of day |
| `ends_at:` | *inclusive* |
| `all_day:` | for an all-day `Time` at midnight, which inference cannot see |
| `id:` | needed by `movable: true` |
| `color:` | `:default`, `:blue`, `:green`, `:amber`, `:rose`, `:violet`, or a host custom property (`"--chart-2"`) |
| `url:` | the agenda row becomes a link |
| `assignee:` / `assignees:` | a name, or `{ name:, image:, status: :done/:pending, label: }` |
| `subtitle:`, `description:` | see [the generic fields](#the-generic-fields) |
| `done:`, `attachment:` | `true`, or `{ label: "…" }` for the words a screen reader hears |
| `attributes:` | merged onto the row's link |

### Events it dispatches

All prefixed `shadcn--event-calendar:`. A menu sends its event only when its
`*_url:` is absent.

| Event | `detail` |
|---|---|
| `select` | `{ date, events }` |
| `month-change` | `{ month, selected }` |
| `view` | `{ view }` |
| `reshow` | `{ showing }` |
| `reshape` | `{ shape }` |
| `regroup` | `{ group }` |
| `show-all` | `{ showAll }` |
| `event-move` | `{ id, from, to, revert }`, see [moving an event](#moving-an-event) |

### Custom properties a host sets

| Property | Default | |
|---|---|---|
| `--event-calendar-sticky-top` | `0px` | where the grid's weekday row stops, below a fixed navbar |
| `--event-calendar-sticky-bg` | `--card` in a Card, else `--background` | that row's surface |

See [the weekday row in a tall month](#the-weekday-row-in-a-tall-month).

## What it borrows rather than rebuilds

**The grid is `Calendar::Month`.** It already builds the weeks, already reads
`Date.beginning_of_week` from the host application, and already knows which days
fall outside the month. The event calendar constructs one and reads it.

**The toolbar is `Button::Component`.** Today, ‹ and › are real buttons with
upstream's classes rather than lookalikes, so `parity_spec` still covers them.

**The date arithmetic in the browser is `shadcn/dates.js`,** extracted from
`calendar_controller.js` when this became its second caller. `parse`, `iso`,
`shiftMonths` and the `strftime` shim now have one implementation — two would
have been two chances to disagree about what `%-d` means. (`addDays` lives there
too but has only this one caller; the calendar does its own day arithmetic
inline.)

## What is genuinely new: `Schedule`

The part of FullCalendar that is neither markup nor a browser. For each week it
takes the events overlapping it, clips each to the week's seven columns, and
gives it the **lowest free lane** — so a three-day event is one bar across three
columns, and two one-day events on opposite sides of the week share the top row
instead of stacking.

Ordering decides who gets the top lane: **all-day first**, then longest, then by
the clock, then by title so a render is stable. Within each of the two groups a
bar that crosses the week is more use above the one-day events than interleaved
with them.

All-day leads because that is what an all-day event *is* — not a thing that
happens at a moment the grid can point at, but a fact about the whole day, and
a fact belongs above the schedule. FullCalendar says it with a separate all-day
row; this port has one set of lanes, so it says it with the sort. Length used to
lead, which read fine until the two disagreed: a *timed* event running three
days took the top lane over a one-day holiday.

That ordering is also the order the events cross to the browser in, so
`Event#sort_key` is the single place it is decided — the controller re-packs the
lanes but never re-sorts.

It renders nothing, so it is asserted on directly — the same reason
`Calendar::Month` is a plain object.

## Three readings, three components

A month answers three different questions, and they are three questions about
what a day *is*:

| | a day is | the cell | the class |
|---|---|---|---|
| events | a **list** of what is on | bars, or marks when it is too dense to name them | `EventCalendar::Component` |
| workload | a **quantity** of work, and whose | the day's total on a heat ramp, then a chip per operator or per job | `Workload::Component` |
| hours | a **timeline** | a 24-hour axis, jobs placed by their clock | `Hours::Component` |

They were one 1,592-line class until the measurements said otherwise — see
[architecture](../decisions/01-architecture.md#when-one-component-grows-a-second-reading)
for what they were and what the seam is. What matters here: **a host never names
a subclass.** `EventCalendar::Component.new(reading: :hours)` hands over from
`.new`, so the API is one component and one argument, and the root is still one
element. `:auto` remains a synonym for `:events`, because the gem is published.

The table is three readings of a *month*, and there are five components: the
two periods that are not the month — `Daily::Component` and
`Weekly::Component` — are subclasses of `Hours`, the reading they draw with, and
are reached the same way, `reading: :daily` and `reading: :weekly`.

`Calendar::Month`, `Schedule` and `Event` are not split. `Chips` — what one job
looks like as a chip, and what a day's total looks like as a badge — is a module
the workload and hours readings both include, because hours is not a kind of
workload: it is a third reading that wants the same chip, so what the two differ
in is the axis, not what an intervention looks like.

### The period, the week and the day

The panel narrows in three steps: **the period** — monthly, weekly or daily —
then how to read it, then the only question that reading has. A month offers
three views and a week two — rows and the timeline; a day has one, so its middle
question is not drawn at all.

**A week is seven `Hours` rows over one `window`**, so Tuesday at ten sits
directly above Thursday at ten. `Weekly::Component` is `Daily`'s sibling, not
its subclass: what the two share is being a period that is not the month, and
`Daily`'s nav steps a day. It overrides six things — `view`, `period`, `grid`,
`title`, `step_button` and `cell_role` — and inherits the axis, the placement and the
panel's one question, chips or bars, untouched.

- **Which week** is the one in the month's grid that holds `selected`, so a week
  crossing two months is not a special case: the grid already carries the days
  either side. A `selected` the grid does not contain falls back to its first
  week rather than raising, as `default_selection` does for a day.
- **The title is the span** — "3 – 9 August 2026", the month said twice when
  the week crosses one, the year too when it crosses that — and `‹` `›` step a
  week.
- **Seven stacked days are a `role="list"`** of `listitem`s, as `Daily`'s one
  day is, and not a grid: the seven-column geometry a `role="grid"` would report
  does not exist here. That is also why neither carries `aria-selected`, which
  ARIA does not allow on a `listitem`; the chosen day is still `data-selected`
  and still a button with its whole date, but a stacked reading has no standard
  way to say "and this is the one you are on".
- **An empty day keeps a full row.** The rows are ragged — each grows with its
  lanes, from nothing to 185px on the fixture month — and two adjacent free days
  take about 160px of an 802px screen. They keep it: *Thursday is free* answers
  the question a week is asked, and a thin strip would say it in a whisper.
  Alignment does not decide it either way, because it is horizontal.
- **It is drawn by the server**, like every `Hours` reading: the nav is links,
  nothing is re-packed in the browser, and `movable:` does not reach it.

**The shape matters more to a week than to a month.** On the busy generator —
ten to twenty-four events a day — the same week measures **1565px at `chips` and
577px at `bars`** against an 802px viewport: two screens against seven tenths of
one, because a row's height follows its lanes and a chip is as tall as a title
and a crew where a bar is a line. The default stays `chips`, inherited from
`Hours`; a host for whom *all seven at once* matters more than what each bar
says has `shape: :bars`, and the panel offers it. An event outside `window` is
reached by scrolling the track sideways, as in the month — which reads worse in
a view you expect to take in at a glance.

**A week can also be drawn as rows** — the month's rows-arrangement row for
each of its seven days: the date column, then the day's chips in a strip
ordered by time, grouped by event or by assignee, with the heat ramp, the chip
cap (`max_chips:`, three by default) and *Show all* exactly as the month's rows
have them. The timeline
answers *when*; the rows answer *what is on, and whose*. A host asks for them
with `reading: :weekly, arrangement: :rows` — a string from `params` works —
and `reading: :weekly` alone, or any other `arrangement:`, is still the
timeline, because the gem is published and an existing call must keep drawing
what it drew. They are `WeeklyRows::Component < Workload::Component`; what
makes either class a week (which week, the span title, the nav that steps
seven days, seven stacked `listitem`s) is the `Week` module both include,
since one is an `Hours` reading and the other a `Workload` one and they cannot
share a parent. The selected day's list stays under the week in both views and
needs `day_url:`, as every server-drawn agenda does. There is no grid for the
week: seven narrow columns are what the rows were built to avoid. See
[its design](../specs/2026-11-10-event-calendar-week-rows-design.md).

Drawing the week as rows found a contrast defect the month's rows had always
had: on the selected day the weekday label is muted text on the cell's
`bg-accent`, 4.34:1. The timeline never met it because its date column carries
`bg-background`, and axe audits the month at a width where it is a grid and the
weekday is hidden. The workload reading now turns that label to `foreground` on
the selected day.

**The week's timeline has no grouping**, because `Hours` has none and the week
adds nothing to the reading it draws with. Cut by operator, a week's row would be a person
rather than a day, on a continuous Monday→Sunday axis rather than seven windows
stacked — a different geometry, not a variation on this one. That and the
week's agenda half, `showing:`, are the two pieces left out of
[its design](../specs/2026-08-31-event-calendar-week-view-design.md#not-in-this-design)
on purpose.

`Daily::Component` inherits `Hours::Component`, because a day is where that axis
finally has room — the same twenty-four hours that were a twenty-eighth of a
page in a month are the whole width here. `showing:` picks its halves, because
they answer different questions: the axis says *when* the day is busy and has
no room for a name, the list says *what* each job is and cannot show a gap.

Cut by operator it becomes a row each, their jobs along the same hours, with the
list below cut the same way and in the same order — which is the question a day
actually gets asked. Not "what is on" but "who is where, and who is free at
two". A job with two people on it is on both rows, because both are on it.

The operator's name has its own slot rather than the date column's: that column
is `w-14` and centres what it holds, which is right for "Tue 4" and clipped
"Katherine Johnson" to "atherine Johnson". Borrowing it would have meant undoing
three of the frame's rules.

**The shape is on a day's panel too, and was not.** `Daily` inherits `Hours` —
the `shape:` argument and the drawing of it both — and its panel listed the
period, the halves and the grouping and never the shape. That did not mean a day
had no shape: it meant a day had one nobody could see or change, and a choice
made in the monthly timeline reached the daily one silently. Measured before it
was believed: the same day rendered at `shape: :bars` and `shape: :chips`
differs, 24,763 bytes against 25,727, one `event-calendar-day-bar` apart.

It is drawn where there is an axis for it to decide — `showing: :axis` or
`:both`, gone under `:agenda` — which is the panel's own rule rather than an
exception to it: a question is on the panel when the view it belongs to is the
view you are in. A system example asserted the panel's exact contents and so had
been holding the defect in place; it now asserts both halves.

`Groupings` is the module the workload and daily readings share for it, the way
`Chips` is the one they share for a chip — the same question of the same data,
drawn differently, and one menu so the two cannot drift apart in what they call
things.

### One options panel

The toolbar had a control for the view, one for the grouping and one for the
shape, and two of them were always about a view you were not in. It has one
panel: **which view**, then the only question that view has.

| view | its question |
|---|---|
| Grid | group by assignee or by event |
| Rows | the same |
| Timeline | draw each job as chips or as bars |

That is the month. A week asks the same question with fewer answers — **Rows**
and **Timeline**, under "Show the week as" — and a day asks none, having one
view. Each period answers `view_choices` and the panel draws the question when
the list is not empty. `view_url:` is handed the same `:rows` and `:hours` from
the week as from the month: telling the week's rows from the month's is the
host's state, since it already holds the period.

`Grid` and `Rows` are the workload reading at its two arrangements and the
timeline is a different reading; that distinction matters to this port and to
nobody using it, which is why `view_url:` is one callback rather than two.
`:grid` is `arrangement: :auto`, not a third arrangement — below `lg` it is rows
anyway, because forcing seven columns onto a phone is what rows were built to
avoid.

**Which makes the two items asymmetric, and only one of them is about now.**
`Rows` forces rows at any width; there is no value that forces the grid below
`lg`, because the `rows` variant's first rule matches on `[data-rows]` alone and
never looks at `data-arrangement`. So *Grid* does not mean "a grid": it means
**wherever there is room for one**. Choosing it on a tablet is not a no-op — the
grid appears when the window passes 64rem — but its effect is deferred, and the
label reads as an instruction about the present. Worth knowing before anyone
"fixes" the item by hiding it under `lg`: that would take away the only way to
say *when it fits, use the grid*.

**The third view reads *Timeline* and is called `hours` everywhere else** — the
key, the reading, the class, and the value a host's `view_url:` is handed. The
divergence is deliberate: "Hours" named the axis it is drawn on, which is a fact
about how it works rather than about what it shows, and the callback's
vocabulary is public API that a rename would break. The day's own halves follow
the label rather than the key for the same reason — *Timeline only* and
*Timeline and list*, not *Hours only* — so the same thing is called the same
thing in the month and in the day.

One callback, but its vocabulary is **`PERIODS + VIEWS`**: it is handed
`:monthly`, `:weekly`, `:daily`, `:grid`, `:rows` or `:hours`, and nothing
stands in for anything else. That last part was learned rather than designed. The *Monthly*
item used to be given `:grid`, which reads as "monthly means grid" — harmless
while the only host merged the two questions into one parameter, and wrong the
moment one kept them apart, because "show me the month again" and "draw the
month as a grid" arrived identical. Leaving the day view sent you back to grid
however you had been reading the month.

A host is therefore free to model the two as two, and the gallery's `density`
does: `period` and `view`, in the order the panel asks them. The comment above
`VIEWS` that justified the merge said the distinction mattered "to nobody using
it"; the first host to keep them apart was the somebody.

**A view is no longer a month's alone.** The week asks the view question too, and
hands `view_url:` the same `:rows` and `:hours`, so a host must read a view
against the period it is showing: `:rows` from the week is the week's rows, and
from the month the month's. A callback that answers every view with the month —
which is what `density` did until the week had views — sends the week's *Rows*
and *Timeline* to the month. `density` now keeps the week when the week is what
is shown.

### The toolbar on a phone

The header was already `flex-wrap`, so the nav went under the title. The nav
itself was one row that could not wrap or shrink. The day's nav is 406px wide
(panel trigger, Today, ‹ and ›), and at 390px the header is 342px, so the page
scrolled sideways on every phone. That is what a host saw in the day view on a
Pixel 7 (412px).

Two classes keep it inside, and neither clips a control:

- the nav is `flex-wrap min-w-0`, so it can be narrower than its row, and
  its controls go onto a second line;
- the title is `min-w-0`. A title too long for the line wraps rather than
  truncating, because `leading-none` with `overflow-hidden` would clip the
  descenders of "agosto".

The panel's trigger was the widest control: a sentence the host translates
("Giornaliero · Timeline ed elenco · Per assegnatario" is 374px), which was
`min-w-0 max-w-full` with a `truncate` label and so ended in an ellipsis on a
phone. It is now an `icon-sm` button with lucide's `settings-2`, the icon
shadcn's tasks example puts on its data table's "View" menu (that example is
not vendored, so this repo does not check it). The sentence is its name, in an
`sr-only` span as the sidebar trigger's is, and the menu it opens shows the
checked items. What a sighted person loses is reading the current view off the
toolbar without opening it. That was a deliberate trade: the title already
says the period and the span.

From 768px up every reading in the gallery fits on one line, so nothing
changes there: the header measures 44px tall, as before. Below that the header
takes two or three lines.

The buttons keep shadcn's sizes, `sm` and `icon-sm`, 32px tall. The toolbar
never had 44px targets, and this change neither grows nor shrinks them. Growing
them on a phone would put classes on `Button` that upstream does not emit.

`previews/phone.html.erb` is the worst case: the day, in Italian, with the
longest date and the longest panel label, in a 390px frame. The frame shows the wrap on a
desktop, but the page's breakpoints still read the window. The system spec
measures every reading at 360, 390 and 412 through device emulation, not
`resize_to`, because headless Chrome will not make a window narrower than
500px. At 500 the day's nav fitted, so the overflow got past the suite.

### The day's timeline on a phone

Below `lg` the day's axis is wider than a phone: 1429px of track in a 340px
grid at 390px wide. `Hours` makes the grid scroll sideways, and nothing in it
takes focus, because the axis is a picture and the jobs open from the list.
axe raised `scrollable-region-focusable` (WCAG 2.1.1, serious), and with
`showing: :axis` there is no list to read the hours past the edge from.

The day's grid is a named region with a tab stop of its own: `tabindex="0"`,
`role="region"` and `aria-label` from `event_calendar.daily.axis_label`
("Hours of the day"). Focused, the arrows scroll it. The ring is the one
shadcn's inputs draw (`focus-visible:border-ring`, `ring-[3px]`,
`ring-ring/50`), outside the frame. An inset ring sat under the rows, which
paint their own background, and showed as a sliver.

It is on at every width, including from `lg` up where the grid does not scroll
and the arrows move nothing. One stop that is sometimes idle was preferred to
a controller adding and removing it as the width changes, which would also
leave a phone without JavaScript with no way in. Only the day: the week's and
the month's timelines hold the day buttons, and Tab on those already brings
the timeline along.

Cut by operator, each row leads with the person's name, and that column is
`sticky` as the date column is in the month's and week's timelines. Before,
it scrolled away with the track, and past the first hours no row said whose
it was. `-ms-2 ps-2` takes the row's 8px of padding into the column. At rest
the name is where it was, and when stuck it keeps 8px from the border. The
ruler's pad shares the class, so the scale stays over the tracks.

### The weekday row in a tall month

A month taller than the window scrolled its column names away, and past the
first week a cell showed its day number but not its weekday. The row is now
`sticky`, `z-10`, and stops at `top-[var(--event-calendar-sticky-top,0px)]`.
That custom property is the host's: unset it is 0, and a host with a fixed
navbar sets it to the bar's height, on `:root` or any ancestor of the
calendar, so the row stops below the bar rather than under it.

Two things had to change for it to stick at all:

- **The frame is `overflow-clip`, not `overflow-hidden`.** Both cut the
  rounded corners. `hidden` also makes the frame a scroll container, and a
  sticky child sticks to its nearest scroll container. The frame never
  scrolls, so the row went up with it (−199px after a 200px scroll, in the
  system spec). `clip` makes no scroll container, so the row sticks to the
  page.
- **The row's background is opaque.** It was `bg-muted/50`, and stuck, the
  cells under it showed through. Each name now carries the `bg-muted/50`, and
  the row under them is opaque with the surface that used to show through the
  tint, so it looks the same. That surface is the page's `--background`, or
  `--card` inside a Card (a `[[data-slot=card]_&]` rule, the way
  `calendar.tsx` turns transparent inside `card-content`). On any other
  surface the host names it in `--event-calendar-sticky-bg`. The first cut
  used `--background` everywhere, and Gestart's dark-palette Card showed it:
  the row was a darker band (tint over 0.145 instead of 0.205). In the light
  palette the two tokens are equal, which is why it did not show there.

What it does not do: it sticks to the nearest scroller *the host* has. If the
calendar sits inside an `overflow-auto` panel, it sticks to that panel, which
is right. If an ancestor is `overflow-hidden`, it sticks to that ancestor
and does nothing visible, and that is the host's to change. The timelines,
whose grid scrolls sideways, are scroll containers of their own, so there the
row does not stick vertically. Only the grid reading has the problem.

### What the server-drawn readings do not ship

The workload and hours readings are drawn whole by the server: their cells hold
crews, clients and clock times that `#portable_events` cannot carry, so the
controller returns before redrawing. They therefore ship neither the events
payload nor the prototypes template — 34 KB of a workload page, 15% of it,
behind a guard that never read it.

Which moves the agenda too. A server-drawn reading renders one only when
`day_url:` names where a day lives: with one the cells are links and what comes
back fills it, without one there is nothing that could.

### A job that crosses days

Three readings, three answers, and none of them repeats a job as if it were
several:

| reading | what a crossing job is |
|---|---|
| events | one bar per **week**, clipped to it, with a flat edge on the side it runs off — FullCalendar's answer, and the port's since its first branch |
| workload | one chip per **day** it covers, each reading the clock that belongs to that day |
| hours | one bar or chip per **day**, clipped to the day: from its clock to midnight, the whole axis, then to its clock |

The workload chips said the job's *first* clock on every day of it — "9:00 AM"
on the third day of a three-day fit-out, a time nothing happened at. They read
the day's own now: the hour it starts if it starts here, the hour it stops if it
stops here, and *All day* if it does neither.

`data-continues-before` and `data-continues-after` are the same two attributes
the bars have always carried, and `rounded-l-none`/`rounded-r-none` the same
rule, so the flat edge means one thing everywhere.

A flat edge says *cut*; it does not say **which** cut. A rail does — 2px of the
event's own colour on the side the chip was severed — so the first day of a job
is marked on its right, the last on its left, and the days between on both. It
was written and did not work for a while: the two rules for `continues-after`
named `border-l` as well, duplicating the pair above them, so all three cases
rendered a left rail and the day a job *started* on claimed to continue from the
day before it. Measured, not read — see [bugs fixed](../decisions/04-bugs-fixed.md).

And the pieces close up. On the cut side a workload chip takes back its cell's
padding and half the grid's line, so five days of one job are one strip rather
than five islands with 13px between each pair. Half a line from each side, so
neither day owns the join; the tint cannot cover that line by itself — a chip's
background is the colour at 12%, and translucent paint over a border shows the
border — but the two rails meeting on the same pixel can. The ends of the band
stay rounded and open; every boundary inside it reads as a tick.

Only in a grid. In `rows` a day *is* a row, its chips scroll sideways, and there
is no next cell to meet — the rule is conditioned so it never applies there
rather than applied and undone, because the `rows:` variant expands through
`:where()`, which weighs nothing, and a reset written that way loses on
specificity whatever order it is given. `not-rows` is a variant of its own,
defined under `rows` so the breakpoint they share is written on one screen.

Both are **logical** edges — `border-s`/`border-e`, `-ms`/`-me` — because
*before* and *after* are positions in time, and in a right-to-left locale before
is the right-hand end. That is a free choice here in a way it is not elsewhere:
these parts are the port's own, and the families that are 1:1 stay physical
because upstream is. `direction_spec` holds it, reading the computed border
rather than the class name, which is identical either way. The hours reading's
axis is still physical and is a separate job — see the todo.

### Why the workload does not draw one bar instead

The events reading draws a crossing job as a single element: `week_row` puts a
**segments layer** over each week — a seven-column grid, absolutely positioned,
`pointer-events-none` and `aria-hidden` — and a bar places itself in it with
`grid-column: n / span m`. One object, spanning, cut only at the week boundary.

The workload reading inherits that layer and renders it *empty*, because
`labelled?` is `reading == :auto`. Filling it was tried, measured and thrown
away.

The geometry was not the problem. Bars landed within 2px of the lane the cells
were holding. Three costs showed up anyway: the layer's row rhythm is the events
bar (22px) and a workload chip is 53px, because the chip carries a client and a
crew; reserving the band's lanes inside every cell comes out of the same `CAP`
the chips are drawn from, so with a two-deep band the cells rendered **60 chips
fewer — that is, none**; and the reservation is per month, so every cell inflates
to the tallest.

What settles it is none of those. **The workload has no agenda.** The events
reading has one, and that is what earns its overlay the right to be
`aria-hidden`: whatever the bars do not say, the agenda reads out in full. In
the workload the chips in the cells *are* the only accessible representation
there is, so a crossing job moved into a hidden layer would simply cease to
exist for a screen reader.

Using it would mean either giving the workload an agenda — but that reading is
"a month as a measure", deliberately without one — or making the layer real
content, which means dropping `aria-hidden` and `pointer-events-none`, and with
them the one-tap-target-per-day property the mobile reading is built on.

That last sentence was written when dragging did not exist, guessing that this
was the direction it would need. It is not what happened: the events reading
drags by a **grip** rather than by the chip, so the layer keeps
`pointer-events-none` and the day keeps its target — and the workload has no
grips because it has no client-drawn payload to move anything in. What stays
true here is the shape of the problem: a five-day job is five chips in a
workload cell, and anything that wanted to drag one would still need it to be
one object first.

### One job, one line across the week

Ordering a cell is not enough to make a five-day job read as one band across
five cells. As soon as a second crossing job starts halfway through the first,
the first one's position moves on the day the second ends. What keeps a job on
one line is a lane it **keeps** — and `Schedule#pack` already computes one per
week for the grid's bars, so `#crossing_on` reads it rather than inventing a
second answer.

It returns the day's crossing jobs indexed by lane, holes and all: a `nil` is a
lane held that day by a job this day does not have, and the cell draws an
invisible chip there rather than closing up. The hole is the feature — closing
it is exactly what moved everything below.

**The order is: one-day all-day, then crossing, then the clock.** A job that is
true of *this* day and only this day reads above one that is as true tomorrow.

That order would cost the continuity the lanes are for — the crossing band
starting wherever the day's one-day jobs leave it — so the first band's rows are
**held open across the week**: as many as its busiest day needs, blank on the
days that need fewer. A five-day job then starts at the same row in every cell,
measured at 89 pixels from the top of all five.

**And only in the grid.** A held row is a grid idea: there a day is a cell and
what lines up is a *row index*, since every chip is full width. In the rows
arrangement a day is a row and what would have to line up is an *x*, decided by
the widths of the chips before it — 193, 202 and 214 pixels for three of them,
because a chip is as wide as its client's name and its crew. No placeholder can
align those, so the strip hides them; the one that was there measured 25 pixels
and bought a meaningless indent.

**Only on the days that have something to align.** A day with no crossing job is
not part of any band, so reserving there bought an empty row and nothing else —
a Monday with eleven jobs and no fit-out opened on a gap. Held rows went from
eleven to four across a month, with the alignment unchanged.

Two things break the band and neither shows in HTML: a held row shorter than a
real one, and a band that starts wherever the day above it ends. The first cost
two rounds — the placeholder is built from a chip's own parts now, and every
chip head carries `min-h-6`, which is what a head with a crew actually measures
rather than the 16px its avatar class suggests.

**All-day is asked of the day, not of the flag.** A job flagged all-day is one
everywhere; a timed job that started yesterday and ends tomorrow is one *today*,
because there is no hour of today it is not on — and its own chip has always
said "All day" there. So the first band holds both, and a timed job drops to the
third on the days it starts and ends, where "→ 5:00 PM" belongs.

Banding by the flag instead put a chip reading "All day" and crossing days below
one reading "All day" that did not. Banding every crossing job by its length
instead put "→ 5:00 PM" above "All day, van off the road". The day is the only
question that gets both right, and it is the question the clock already asks.

The lanes are ranked among the band's own jobs, not by `pack`'s numbers. Those
are assigned over *every* event in the week, so a job outside this band holding
a low lane left a hole at the top of every cell the crossing job appeared in — a
lane nothing could fill, because its holder never arrives here.

**A cell reads in three bands**, not two: a job that is all day *and* crosses
days, then the single-day all-day ones, then everything with a clock in clock
order. The first band is the standing fact about that day — the depot is shut,
the crew is away on a fit-out — and it holds true before and after it, so it
sits above the facts that are only today's. Length does not sort within a band
the way the grid's lanes do: inside one day a five-day job and a two-day job are
both simply on.

An all-day job is ranked by its **date**, a timed one by its clock.
`Date.new(2026, 8, 20)` and `Time.zone.local(2026, 8, 20)` are the same midnight
to a reader and two different integers to `to_time` — one in the system zone,
one in the app's — so two all-day jobs on one day used to order by which way
their start had been written.

The hours axis draws nothing for a job the window does not contain. Clipped to
an empty interval it came out zero-length pinned to an edge — and a chip that
short is content-width, so a 5am callout on an 07–19 axis was a full-width label
sitting on the 7:30 job it shared lane zero with.

Its gridlines are spaced by `--gridline`, one mark's share, so the lines and the
labels above them are the same divisions. A flat 12.5% agreed with the labels
only where the window divided into eight: a 07–19 axis drew six against eight.

In the hours reading a chip's width is what it **occupies that day**, not what
it is flagged: an all-day job and the middle day of a crossing one are both the
whole axis, and a job with a real duration is drawn at it once there is room to
read one. The threshold is the packer's own floor, which already says how much
room a chip needs — below it a chip could not be read at its duration anyway,
so it stays as wide as its text.

**The count is not deduplicated, and that is deliberate.** A five-day job counts
on each of its five days, because the workload reading answers "how much work
does this day hold" and the crew is engaged on all five.

### Navigated by URL, not by the browser

`reading:` picks the reading and, within the events one, the busiest day picks
between bars and marks.

**The server-drawn readings navigate by URL.** Its cells hold crews and titles
that `#portable_events` does not ship, so there is nothing in the browser to
rebuild them from — and shipping them would mean every assignee of every month
travelling to every page, plus a second copy of the cell in JavaScript, for the
one reading whose data is exactly what should not travel. `month_url:` turns the
nav into links; without it the nav announces `month-change` and leaves the DOM
alone. The events reading redraws in the browser as before.

## Two arrangements, and what picks between them

Not one scaled down. A cell either **names** its events or **shows their
shape** — never half of each — and which one it does is decided per calendar by
the busiest day in the month.

| | labelled (busiest ≤ 12) | dense (above that) |
|---|---|---|
| below `sm` | marks | marks |
| `sm` and up | bars, and "+2" when a cell runs out of lanes | marks |

**Marks** are one small square per event, all of them, sized against the
busiest day and grouped into colour bands. **Bars** are the labelled reading:
`Schedule` packs them so a three-day event is one bar across three columns.

A 48px phone cell can hold a title or be legible, not both, so below `sm` there
are never bars. And past a dozen events a day, "+79" stops being information at
any width: the three bars above it are an arbitrary sample, the number is the
only thing on the cell, and what it counts is invisible until you open the day.
`DENSE_ABOVE` is where that line sits.

### Why the marks are banded rather than chronological

This is the one place the marks disagree with the agenda, and it was measured
rather than assumed. Chronological marks were built first, and a month of them
reads as confetti: at four pixels nobody can tell *which* event a mark is, so
ordering by time buys nothing — and it costs the only thing a cell that size can
say, which is what kind of day it is.

Grouped by colour, a cell is four or five bands, and two cells can be compared.
Ordering the bands by the palette rather than by size is what makes them
comparable, because a colour then sits in the same place in every cell. Inside a
band the clock still decides, and the sort is stable on both sides — Ruby's
`sort_by.with_index`, JavaScript's `Array#sort`.

Adjacent marks that share a colour close the pixel between them and square off
their join, so a band reads as one bar rather than as a row of beads; marks of
*different* colours keep the pixel, which is the only separator a 4px square can
afford. That is the calendar-UI writing's "faint difference of highlights, which
act as rules" — done with the colours already in the data instead of with lines
drawn over them.

`:default` is the quietest mark rather than the loudest, and it did not start
that way. It was `--primary`, which in the neutral palette is near-black and at
four pixels carries about twice the weight of the 500-level hues beside it; a
month of marks made that obvious and nothing before it had. It is
`--muted-foreground` now, which is what *uncategorised* should look like — and
what the chip always looked like anyway, since `primary/12` is a light grey.

### What the density costs, and what was done about it

Two thousand events is where the design's bills arrive, and both were paid:

- **Every rule a mark obeys lives on the strip**, not on the mark. The class
  string repeated two thousand times was half a megabyte of HTML for a rule that
  never varies. A mark carries `data-color` and its two run attributes, and
  nothing else.
- **The crossed payload leaves out what can be worked out** — `to` when it
  equals `from`, `meta` when it equals `time`, `allDay` when false, `url` and
  `id` when absent. `eventsValueChanged` fills them back in once, on the far
  side, rather than at each of the several thousand places that read an event.

What is *not* solved is that a dense month still ships every event to the
browser so the controller can redraw it. At this density a host should feed
months on demand instead, and `month-change` is the hook for it.

**The redraw is not where the time is, and that is measured.** A 2,000-event
month redraws in 19.4 ms in the browser — against 54 ms to render a smaller one
on the server. Half of it is `ticksElement`, and inside that the sort is 0.4 ms
and the nodes 1.4: the rest is the DOM taking two thousand spans. The obvious
client-side optimisations were profiled and are worth between nothing and 1.5%;
the numbers are in [the todo](../todo.md) so nobody re-derives the proposal
without them.

**The index is an index.** `Schedule#by_day` used to be a Hash whose default
block scanned *every* event for the ones covering that day — once per day, so
forty-two full scans over a month, rebuilding an enumerator and its pairs each
time. One walk now drops each event into the days it covers, clamped to the grid
so an event running for years costs the days on screen rather than the days it
lasts. Measured on 1,182 events: building the schedule 23.9 ms → 8.8 ms, the
whole render 74.2 ms → 54.3 ms, allocations 149,114 → 102,032. The 147 snapshots
are byte-identical, which is what says the ordering survived.

The default block stays, and it is not vestigial: `#on` is public and `busiest`
was once broken by a day outside the grid, so a scan still answers for those.
`Hash#merge` keeps the receiver's default proc — that is what lets the index
answer for the grid and the scan for everything else.

**Before any of that, turn compression on.** It is worth more than everything
else here put together and it is one line in a host, not a line in this gem.
Measured on a real payload extended to two thousand events:

| | over the wire |
|---|---|
| as it ships today | 294 KB → **9.7 KB** compressed |
| re-encoded column-wise, keys dropped | 218 KB → **9.4 KB** compressed |

Thirty times against three and a half percent. Repeated JSON keys are the thing
gzip removes best, so an encoding invented to remove them by hand buys almost
nothing and costs a payload no one can read in an inspector and a decoder in the
controller. It was measured rather than assumed, and the measurement is the
reason the payload is still an array of objects.

The catch, and it is why this paragraph exists: **Rails does not compress by
default.** `Rack::Deflater` is not in a new application's middleware and the
dummy here has none, so a bare Rails app serving a dense month sends the whole
294 KB. Compression usually arrives from a proxy or a CDN rather than from the
application, which is exactly why it is easy to assume and worth checking — a
response with no `Content-Encoding` header is the check.

What the `.compact` above still buys is the half compression cannot reach: the
bytes never built, never parsed, and never turned into objects on the far side.

### An all-day event, in each of the three readings

Marked with `all_day: true`, or inferred from a `Date` — which has no time of
day to show. What it means is the same in all three and looks different in each:

| reading | where it goes |
|---|---|
| grid | the top lanes, above everything with a clock |
| rows | first in the cell, its chip reading "All day" instead of a time |
| hours | the top lane, `0%` to `100%` — the whole axis, because it has no hour to be placed at |

Only the grid needed anything doing: the other two already sort by
`#day_sort_key`, which has always led with all-day, and the hours axis already
treated a day-long event as the full window.

### Rows, and the button that asks for them

The workload reading is one row per day below `lg` and the seven-column month
above it. The rows are the better view of a busy month at any width — a row has
space for a clock, a crew and a client where a 46px cell has room for none of
them — so the toolbar can ask for them on a desktop too. `arrangement:` is
`:auto` (the breakpoint decides) or `:rows` (it does not). There is no `:grid`:
forcing seven columns onto a phone is the thing the rows were built to avoid.

The fifty-two rules that make up the arrangement had been written as
`max-lg:data-[rows]:`, which is a media query and therefore not something a
button can reach. Writing each one twice — once for the breakpoint, once for the
override — would have been fifty-two more tokens to keep in step, and this file
has already lost three rules to a class list edited in one place and not the
other. So `shadcn.css` declares a variant instead, beside the `dark` one it
already ships:

```css
@custom-variant rows {
  @media (width < 64rem) { &:where([data-rows]) { @slot } }
  &:where([data-rows][data-arrangement="rows"]) { @slot }
}
```

One token, two rules, and the unconditional one second so that above `lg` the
override wins — `:where()` holds both at zero specificity, which is what leaves
source order in charge. A host gets it for free: the installer writes an
`@import` of `shadcn.css` into their Tailwind entrypoint, which is the same road
`dark` travels.

The toggle itself is a link when `arrangement_url:` names the other state, and a
`data-action` otherwise — the shape `show_all` and the grouping menu both have.
Unlike those two it *could* have been client-side only, because it changes no
markup: `arrange` flips the attribute and the stylesheet does the rest, with no
round trip. It is offered as a URL anyway because the workload month is drawn by
the server, so a flip made in the browser is gone the next time the month is.

A pressed toggle is the **solid** button among outline ones — `nav_button`
swaps `variant: :outline` for `:default` — which is what shadcn does wherever a
selection sits in a row of buttons, and it costs no class of ours. Not
`aria-pressed:bg-accent`, the shape `Toggle` uses: an outline button's *hover*
is already `bg-accent`, so pressed and hovered would be the same picture and an
unpressed button under the mouse would read as on. `Toggle` does not have that
problem because its own hover is `bg-muted`. This is what "Show all" was
missing too.

The button is hidden below `lg` with `max-lg:hidden` rather than by a condition
in Ruby. There the rows are already what is drawn, so it has nothing to change —
and the server cannot know which side of the breakpoint it rendered for, so CSS
is the only place that can decide.

## Moving an event

`movable: true` and nothing else. The calendar dispatches
`shadcn--event-calendar:event-move` and stops there; saving is the host's, the
way `month-change` is.

```erb
<%= render(Shadcn::EventCalendar::Component.new(events:, movable: true)) %>
```

```js
move({ detail: { id, from, to, revert } }) {
  patch(`/appointments/${id}`, { starts_at: from, ends_at: to })
    .catch(() => revert())
}
```

**It needs an id on every event, and raises without one.** `Event#id` is `nil`
unless a host passed one — it existed for the payload the controller reads and
nothing had needed it since. A move without one would dispatch `id: null` and
fail as "dragging does nothing", days later and in somebody else's code, so it
is an `ArgumentError` at render naming the event that has none.

### Two hands, one rule

**From the keyboard, through the agenda.** `Space` on a row takes that event and
hands the focus to the selected day; the arrows move; `Space` puts it down;
`Escape` puts it back and returns the focus to the row. The agenda is not a
convenience here, it is the only place available: the bars are `aria-hidden`,
because the agenda reads the day out in full and that is what earns them the
right to be decoration — so a tab stop on a bar would be an `aria-hidden-focus`
violation rather than a choice. It costs nothing, and it pays: a crossing event
is one *row* in the agenda where it is a bar per week on the grid, so picking
there never has to ask which object was meant.

**From a pointer, through a grip.** The leading edge of a bar, and the agenda
row's colour bar. Not the whole bar: with the bar grabbable, the day underneath
lost the centre of **17 of the 27 days that had events** and clicking one
stopped working at all — the one-tap-target-per-day property this component is
built on, gone. With a grip it is 0 of 27, and 1% of the cell rather than 40%.
The layer stays `pointer-events-none`; only what a grip stands on is taken.

**Both shift by how far you moved from where you took hold**, and differ only in
what taking hold can mean. A grip on the grid is a day, so a bar grabbed on the
Wednesday of a Monday–Friday event and dropped on the Thursday moves one day;
and a bar is clipped to its week, so a crossing event has a grip per week and
the second takes hold of its own Monday. A row is the day whose agenda it is.

That rule was arrived at twice. The design first said the agenda shifts against
the event's own *start*, "because the agenda is not on the grid and has no day
to be relative to" — and it is a day's agenda, so it has one. The example that
caught it: a 19–21 event picked from the agenda of the 20th, one press of →,
21–23.

### The value is the state

A move assigns the events value rather than mutating the controller's copy of
it. That is what lets a Turbo morph correct the browser without the host's
help — and it was the other thing arrived at twice, because a move that mutates
the copy never touches the attribute, so a morph carrying the server's answer
back is a change only when the server disagreed with what the page already had.
A refusal, by definition, does not. See
[02-javascript.md](../decisions/02-javascript.md#controllers-re-sync-on-turbomorph).

Writing the whole payload was measured before it was believed: 1.08 ms at two
thousand events for the round trip, 0.14 ms at two hundred. Under a frame.

`pending` rides on the event until the server's payload lands, drawn as
`data-pending`. `revert()` travels in the detail for the host that answers a
refusal with a toast alone and never redraws the calendar.

A picking, a move and a putting-back each say so in an `sr-only`
`role="status"` of their own. Not the caption's: that is the calendar's other
status region, it holds the month, and the controller rewrites it on every
navigation.

### What it does not do

- **A drop onto a full day is invisible.** Only `lane <= max_events` is drawn,
  so an event dropped on a day already at the cap joins the "+N more". The move
  succeeds and nothing appears.
- **A morph resets the selection** to what the server rendered — measured, the
  20th chosen and the 3rd after a refresh. A host doing morph refreshes has to
  round-trip the selected day.
- **Touch at `sm` and above is unmeasured.** Below `sm` the bar layer is
  `display: none` and there is nothing to grab, so a phone is not the question;
  a tablet at ≥640 CSS px has bars and a finger, and nobody has run it.
- **The grip is 8×22 px**, under WCAG 2.2's 24×24 for Target Size (Minimum). The
  argument for it is the "equivalent control" exception — the agenda row's grip
  is larger and the keyboard does the same job — and it is an argument, not a
  measurement.
- **A `pointercancel` puts it back** rather than dropping it where the pointer
  happened to be. It is the one branch here no spec can reach: Selenium cannot
  cancel a pointer.

## What an event says, and where it opens

Written for a host that needs an event to say more than a title and a time, to
wear its own colour, and to open somewhere the host decides. The design is
[its spec](../specs/2026-11-09-event-calendar-event-content-design.md); this is
what was built, read back from the code.

### The generic fields

`Event` takes five more keywords, all optional (`subtitle:`, `description:`,
`done:`, `attachment:`, `attributes:`); `color:` is widened to also take a
custom property's name, as a String only (a Symbol, `:"--chart-2"` included, is
read as a palette name and falls back); and an assignee takes `status:`. A host that passes none of
them renders what it rendered before (the goldens outside the `<template>` did
not move).

| keyword | drawn as |
|---|---|
| `subtitle:` | the chip: on the title's line, after it. The row: the same. |
| `description:` | the row only. A sentence does not fit a chip |
| `done:` | a check icon, in the chip's head and beside the row's title. `true`, or `{ label: "…" }` |
| `attachment:` | a paperclip, in the same two places. `true`, or `{ label: "…" }` |
| `attributes:` | merged onto the row's link, nowhere else |
| `color:` | see below |
| an assignee's `status:` | `:done` or `:pending`, a badge on that face. Anything else is nil and draws none |
| an assignee's `label:` | what the badge says to a screen reader. Kept only beside a valid `status:` |

The gem gives `title`, `subtitle` and `description` an order and no meaning.
`attachment:` is one boolean because whether the attachment belongs to the
record or to something under it is the host's to collapse. The icons' accessible
names are the `event_calendar.done` and `event_calendar.attachment` keys, and
the badge's are `event_calendar.assignee_status.*`.

**Unless the host gives its own words.** Those keys are generic on purpose —
"Done", "Has an attachment", "Pending" — and a host usually means something
narrower by them. So each of the three takes a `label:`, read out instead:

```ruby
done: { label: "Service completed" }                     # instead of true
attachment: { label: "Has a signed report" }             # instead of true
assignees: [ { name: "Mario Rossi", status: :done, label: "Mario signed" } ]
```

A flag given as a hash counts as `true`; `false` and `nil` still draw nothing,
and a blank label is no label. A boolean keeps working as it did, so nobody
passing one changes. Two keys, `done_label:` beside `done:`, were the other
shape and were not taken: they allow a label with no flag, which means nothing,
and the hash cannot say that. An assignee's `label:` without a valid `status:`
is dropped, as an unknown `status:` already is — there is no badge to put it on.

The gem does not interpret the words; it puts them where its own would have
gone, as text (escaped, never markup), in the chip, in the row, and in the month
the browser draws, whose payload carries them as `doneLabel`,
`attachmentLabel` and an assignee's `label` beside the values it already had.

The chip is `Chips#chip_head` and `#chip_text`, so the hours, week and day
readings and the workload grouped *by event* all carry the new fields; the
`bars` shape of `Hours` and the month events reading's bars (dot, time, title)
were left as they were. The helpers the chip and the row share, avatars, badge
and the two icons, live in `EventCalendar::Faces` (`faces.rb`), because neither
includes the other.

The row gained the assignees' avatars, their badges and the `+N`, which it did
not draw before. That is a builder's call: the row is where an event is read in
full, and without it a status would be visible nowhere in the month.

### The chip is decoration, the row is the link

A chip is drawn inside the day's target, which is an `<a>` (with `day_url:`) or
a `<button>`. A link inside either is invalid HTML, and one target per day is
the property the mobile reading is built on. So the chip is not made a link, and
an event opens from its **row in the day's list**.

That puts a condition on every reading: the list has to exist. In the code,
`agenda?` is true when the reading is drawn by the browser or `day_url:` is
given (`component.rb`, `#agenda?`). **For the server-drawn readings (the month's
hours and workload readings, the week) the list needs `day_url:`**, because the
server is what draws the chosen day. This is the contract, documented rather
than answered with a second list that works without it: a host that wants events
to open passes `day_url:`. The day reading has its rows under `showing: :agenda`
or `:both`.

The row's `<a>` takes the event's `attributes:`. Precedence is the gem's usual:
the component's defaults, then the caller's, then `href` and `data-slot`, which
stay the event's and the gem's; `class`, `data-action` and `data-controller`
concatenate. A `class` goes through the same pipeline as any caller's, so a
Hash or an Array means what it means on any other component. `as:` and `size:`
are `Item`'s arguments, not attributes, and are dropped from `attributes:`: the
row stays a small `<a>`. An attribute name no element can carry (`"on click"`)
is escaped the way Rails' `tag` escapes it (`on_click`), on the server's row and
in the payload alike, so the browser's `setAttribute` never throws on it. Without
`url:` there is no link, and `attributes:` are dropped. A drawer is
`attributes: { data: { turbo_frame: "event", action: "shadcn--dialog#open" } }`.
There is no JavaScript event and no id emitted: what a click shows is the
server's, and with no `attributes:` the row is a plain link that still works
with JavaScript off. The `event_links` preview (Lookbook) shows one event
opening in a Sheet and one going to its page; the dummy app answers
`/calendar/events/:id`.

A movable row with a `url:` is one tab stop, the link: Enter opens, Space picks
up. The `<li>` keeps `tabindex="0"` only when the row has no link.

**The browser-built month** draws these rows from the payload and the
`<template>`. Two costs worth knowing:

- The payload carries the row's fields (`subtitle`, `description`, `done`,
  `attachment`, `assignees`, `attributes`) only when the browser builds agenda
  rows, which is `agenda?` without `day_url:` (`Component#client_rows?`).
  A host already passing `assignees:` to that reading pays more bytes per event
  than before. Absent fields cost nothing, as with every other key.
- A host `class` in `attributes:` is **appended** by the browser
  (`classList.add`) where the server tailwind-merges it. A known difference;
  a host class that is meant to *replace* a gem class will do so on the server
  and not in the browser-built month.

### The host's colour is a mark, with neutral ink

`color:` still takes the six names. It also takes the **bare name of a custom
property**, `color: "--chart-2"`, matched by `Event::HOST_COLOR`
(`/\A--[a-z0-9-]+\z/i`); anything else falls back as an unknown name always did.
Only a bare name is accepted because it ends up inside a `style` attribute.

The gem writes it inline as `--event-color: var(<name>)` with
`--event-ink: var(--foreground)`, so it drives what the fixed colours drive (the
dot, tick, agenda mark, crossing rails, the tint behind a chip and the `bars`
fill) and beats the `data-color` rules without editing them. `COLOR_TOKENS` is
untouched. The ink stays neutral because the gem cannot know the contrast of a
colour it was not given; a yellow token as text on a card is the case that
fails. Dark mode is the host's: it defines the property under `.dark`.

**A filled block, the chip painted in the host's colour, was not done**, for the
same reason: it needs a readable foreground derived from an unknown colour. A
mark and a neutral text need none.

The dense reading's marks band by colour, and every host colour is `:host`
(`"host"` in the payload, which the component spec asserts), so the property is
half of what a band is: `Component#in_bands` sorts by the palette's rank, then
by `color_property`, and `#same_band?` compares both, so two host colours band
apart as two fixed colours do. The controller's `ticksElement` does the same
with `color` and `colorProperty`. Host colours sit after the six, ordered by
plain string comparison of the name. Covered on the server by the component
spec and in the browser by a system example that steps a month away and back;
not looked at in the gallery, which has no day with two host colours.

### The host slot that was rejected

An empty slot per event, filled with the host's markup and told whether it is
drawing a chip or a row, was the first idea. It was dropped as the more complex
road: the events reading is drawn in the browser by cloning templates, so host
markup would have to travel to the client for every event, and the `bars` shape
and the workload's per-operator chips have no room, or no single event, to put it
in. Generic fields drawn by the gem cost none of that.

## Where it diverges from FullCalendar

**`ends_at` is inclusive.** FullCalendar's `end` is exclusive, which is right for
arithmetic and wrong for everyone who has ever typed a date: an event held on the
19th, 20th and 21st is written here as `starts_at: 19th, ends_at: 21st`. This is
the only deliberate divergence in the data model.

**No `+N more` popover, no week/day/list views, no resize, no recurrence.**
Named here rather than left to be discovered — see *Not done*. Moving an event
*is* here, behind `movable:`, and it is the one of these that came off the list.

**Colours cascade over two levels, where FullCalendar has three.** An event's
own `color:` wins; failing that the calendar's `default_color:` applies; failing
that the event is uncategorised. That middle level is FullCalendar's *event
source* colour under another name, and it exists so a calendar of one kind of
thing says its colour once rather than on every row of a `map`. What is missing
is their outermost level — a global default across calendars — which a Rails app
expresses by wrapping the component, not by a setting.

A colour name that is not in the palette falls to `default_color:` rather than
to grey: a typo in one row should look like the rest of that calendar.

**Colours are a fixed palette**, `:default :blue :green :amber :rose :violet`.
Free-form is not available and could not be: Tailwind never sees a class built at
runtime, and a hex has no answer for the dark palette. Each name resolves to two
custom properties declared once on the root, so an element is recoloured by
setting one `data-color` — which is what keeps the colour table out of the
controller.

The inks are the 800/300 pair rather than the 500 the dot uses, and both halves
were measured rather than chosen: 500 on a 12%-tinted background is around 3:1,
and 700 is **4.41** — under AA by nine hundredths, which is exactly what
`accessibility_spec` exists to catch and an eye does not.

That pairing is the one place this port is *stricter* than upstream, and it was
measured on their own demo rather than assumed. FullCalendar v7 ships the same
shape — two custom properties on the event element, `--fc-event-color` and
`--fc-event-contrast-color` — but **derives nothing**. Nothing about FullCalendar
is vendored here, so every claim in this file about it was read off its own
documentation and measured in its live demo, never from source: setting the colour to a
pale yellow on a live event leaves the contrast at `#fff`, and it renders white
on cream without complaint. Here a colour name resolves to a *pair* that axe has
already checked, which is what a fixed palette buys in exchange for not
accepting a hex.

## What a cell costs

A month of 447 events used to be **1157 KB of HTML and 131 ms of render** for
ninety-three visible chips. Two decisions compounded, and both were made when
they were cheap:

**Every chip was rendered and CSS hid the fourth onwards**, so *Show all* could
be a class toggle with no round trip. Eight hundred of the eleven hundred avatar
components on the page were never seen. `show_all:` is state now — the server
renders what a cell shows, and the toggle is a link to the other state when the
caller names its URL. Three of the file's gnarliest class strings went with it.

**Every avatar carried `data-controller="shadcn--avatar"`.** The controller's
whole job is swapping the image for the fallback once it has loaded or failed,
and `connect()` returns immediately when there is no image — so eleven hundred
Stimulus instances were doing nothing. `Avatar::Component` attaches it only when
it has an image now, which is a gem-wide saving.

**Both cuts of a cell were rendered and the menu hid one**, which made switching
free and everything else twice as expensive. `group_url:` finishes what
`show_all:` started: a cell renders the grouping it is showing, and the menu
items are links to the other one.

Measured after, warm, on the same 447 events:

| grouping | render | HTML | avatars |
|---|---|---|---|
| by assignee | 32 ms | 277 KB | 87 |
| by event | 46 ms | 382 KB | 218 |

Against 1157 KB and 1136 avatars before. The pattern the three fixes share is
one sentence: **the cheapest thing to render is the thing nobody will see, and
the way to stop paying for it is to stop rendering it.** Every toolbar control
in this reading is now state the caller owns, and a link when the caller can
name the URL of the other state.

## The keyboard

`role="grid"` on the weeks, `role="row"` on each, `role="gridcell"` and
`aria-selected` on each day — the pattern `Calendar` has implemented all along,
and which this component went without for its first iteration: forty-two
tabbable buttons, no arrows, no geometry, and `aria-pressed` announcing every
unselected day as a toggle that is not pressed.

One tab stop for the month; the arrows move within it, `Home`/`End` reach the
ends of a week, and `PageUp`/`PageDown` cross a month — a step off the grid's own
edge navigates, and the tab stop travels with the selection.

`aria-selected` is the fact; the **outline** is whether anyone can see it. The
tint alone separated a selected cell from a plain one by 0.030 of perceptual
lightness in the light palette — `oklch(0.97)` against `oklch(1)` — where the
dark palette got 0.124, so clicking a day read as nothing happening in the
palette most people use. A 2px solid `--ring` outline carries it now, and each
half of that was forced rather than chosen: a *ring* would have been the same
CSS property as `focus-visible:ring-[3px]`, so Tailwind's order decided between
them and selection won — a focused cell and a merely selected one rendered
identically, which is worse than the fault being fixed. An outline is a
different property, so the two stack. And `--ring` rather than `--primary`
because the day *number* already wears primary when it is today; the gem's
`Calendar` spends primary on selection precisely because its today is the quiet
one, and this family made the opposite trade first.

**Neither state raises the cell**, and that took a second pass to get right.
Both `focus-visible` and `data-[selected]` carried `z-10`, to keep their
decoration off the neighbouring cells — and a cell is opaque and sits under the
absolutely positioned bar layer, so raising it painted its own background over
every bar crossing it. A selected day showed no events at all while the agenda
underneath listed them, and the same was true, for longer, of the day a keyboard
was standing on. The lift bought nothing either time: both decorations are drawn
*inside* the cell's box — `outline-offset: -2px`, `ring-inset` — so no neighbour
could ever have clipped them.

The roles describe the seven-column month. When the workload reading lays the
same DOM out as one row per day, what a screen reader reports and what an eye
sees disagree there. That is the price of one tree serving two arrangements, and
it is the trade the Sidebar documents for the same reason. The toolbar's Rows
toggle widens that gap deliberately rather than introducing it.

## The controller, and the two rules it is written to

The month exists twice — `Schedule` packs it on the server and
`event_calendar_controller.js` packs it again for every month reached from the
nav. That is the duplication this design accepts, and the same two rules that
keep `calendar_controller.js` honest keep this one honest:

1. **No text of its own.** Month and weekday names, the patterns they are
   arranged in, the "+2" template and the plural forms all arrive as values from
   `I18n`. A `toLocaleDateString` would answer to the *browser's* locale, and the
   month you navigated to would be spelled differently from the one you started
   on. Plurals go through `Intl.PluralRules`, because "one or other" is wrong in
   every language with a few and a many.

   **Times never cross as a pattern at all.** `shadcn/dates.js` stops at dates on
   purpose, so the server formats every time and ships the finished string with
   the event.

2. **No class of its own.** Every shape it builds is cloned from a `<template>`
   the component renders, so Tailwind — which scans Ruby, not JavaScript — has
   already seen every class that can appear. What it sets instead are `data-*`
   attributes the Ruby styles with `data-[…]:` variants.

   The two exceptions are grid line numbers, `grid-column` and `grid-row`, which
   are what `col-start-3` compiles to anyway — and the component writes them the
   same way, so the two sides cannot drift.

`spec/system/event_calendar_spec.rb` opens with the example that matters: press
› then ‹, and compare every cell, every state, every label and every bar's
position against what the server would have drawn for the same month.

## The day view, and letting a host own it

`shadcn--event-calendar:select` fires on every day click with the date and the
day's events, and a host can do whatever it likes with it. For the common
thing — open a drawer, swap a panel — an event is the long way round: a
listener, a URL built by hand, and `Turbo.visit` called for you.

`day_url:` is the short way. The cells become links, and the built-in agenda is
the day view they swap:

```erb
<%= render Shadcn::EventCalendar::Component.new(
      events:,
      day_url: ->(date) { calendar_day_path(date) },
      day_attributes: { data: { turbo_frame: "day" } },
      agenda_as: :"turbo-frame", agenda_attributes: { id: "day" }
    ) %>
```

Two things a host meets on the way, neither of them guessable from the markup.

**`--event-color` does not reach outside the calendar.** It is declared as a
descendant rule on the calendar's own root, so a day view rendered in a panel —
a sibling, not a child — gets nothing, and a dot painted `bg-(--event-color)`
comes out transparent. `EventCalendar::Component::COLOR_TOKENS` is the same
declaration as a constant: a host applies it to whatever container holds the
colours and cannot drift from the palette by copying it.

**Turbo replaces a frame's contents, not the frame.** The element that stays in
the DOM is the one the host rendered, with the classes it was given, so anything
written on the response's own `<turbo-frame>` tag is discarded on the first
swap. Both facts were found the same way: applying the constant to the frame
changed nothing, and applying it to the list inside worked.

Nothing here names Turbo — `agenda_as:` takes an element and the host chooses
which. It is the same shape `as:` has everywhere else in this gem, and the same
shape `month_url:` has for the nav.

**A link and a selection cannot share a gesture**, so with a URL the click
navigates and the controller's `select` is left off the cell: the server decides
what the day shows and `aria-selected` follows it. The agenda's Stimulus targets
come off with it, and `renderAgenda` returns early rather than racing a frame
swap — as does the `aria-live` on the region, which existed because the agenda
used to change under a pointer that never left the grid. A frame swap is a
navigation, and Turbo announces those itself.

What does not change is the grid: a cell is still `role="gridcell"`, still
carries the roving tab stop, and the arrows still move across it.

The worked example is **`density` with `turbo` set**, and it offers the two
shapes a host can give the day, which are different things rather than two
skins:

- **panel** — a Sheet that opens *over* the page, so one click both fills the
  frame and opens it. `density` assembles the calendar's arguments and hands
  them to a template, because a Sheet's content is a slot and a slot needs a
  block, which a preview method cannot write.
- **agenda** — the component's own agenda *is* the frame, through `agenda_as:`.
  No markup at all, but it sits under six weeks of grid: it updated 335px below
  the fold and the click read as nothing happening, which is what Turbo's
  `autoscroll` is for and what a panel never needs.

That template is also the `panel` preview, `@hidden` so the gallery keeps one
playground. It has to exist rather than being a loose template: `snapshot_spec`
reads the file, but `accessibility_spec` visits `family/name` as a *preview*, so
a template with no method of that name has no URL and its axe example 404s.

The half a preview cannot hold — a model, a route, a controller and the frame's own
markup — is in `test/dummy`, for the reason `/chat` is there for the message
scroller. The model is a plain object rather than an ActiveRecord one, which is
the more useful shape for the thing being shown: **a component never sees a
record.** `Appointment.for_calendar` maps ten fields down to six, and the four
that stay behind — where it is, who to ring, what state it is in, the note from
last time — are what appears when a day is opened.

## Lazy loading, when a host needs it

The events a component was given are the ones the server had, and the month you
navigate to may have others. So navigation dispatches

```js
document.addEventListener("shadcn--event-calendar:month-change", (event) => {
  // event.detail.month === "2026-09-01"
})
```

and choosing a day dispatches `shadcn--event-calendar:select`. Replacing the
component over Turbo in response to the first is the whole of lazy loading here,
and `month_url:` is the version of it that needs no JavaScript at all — the nav
becomes links and Turbo does the rest. Nothing about the default path needs
either: a calendar handed an array works with no server round trip.

**What to load, when the table holds years.** Without `month_url:` the nav is
client-side, so the browser must already hold every month it can reach — which
is why `buildIndex` is deliberately not clipped to the month on screen. Hand a
five-year table to a calendar showing one month and every one of those events is
queried, wrapped, serialised, parsed and indexed to draw thirty-one days. With
`month_url:` the host queries a grid at a time:

```ruby
month = Shadcn::Calendar::Month.new(Date.parse(params.fetch(:month, Date.current.to_s)))
grid = month.days.first.beginning_of_day..month.days.last.end_of_day

Appointment.where(starts_at: ..grid.last).where("ends_at IS NULL OR ends_at >= ?", grid.first)
```

Two traps, and both are silent — the calendar draws, it is just missing things.

**Query the overlap, not the start.** A job that began last month and runs into
this one starts outside the range and belongs inside it. `starts_at` between two
dates loses exactly the multi-day events the lane packing exists for.

**The range is the grid, not the month.** `month.days` is 35 or 42 days, not 28
to 31: August 2026 runs 27 July to 6 September, eleven days of it outside the
month, and those cells show their events like any other. `Schedule` indexes the
grid's own first and last day for the same reason. A query bounded by
`month.first..month.last` leaves the first and last rows wrong.

### A host's half, end to end

Three things in the controller and nothing else: normalise the month, query the
grid, map.

```ruby
class CalendarController < ApplicationController
  def show
    @month = Shadcn::Calendar::Month.new(month_param)
    grid = @month.days.first.beginning_of_day..@month.days.last.end_of_day

    @appointments = Appointment.includes(:client, :assignees)
                               .where(starts_at: ..grid.last)
                               .where("ends_at IS NULL OR ends_at >= ?", grid.first)
  end

  def day
    @date = Date.parse(params[:date])
    @appointment_list = Appointment.includes(:client, :assignees).on(@date)
  end

  private

  # `Date.current` when absent or unparseable: a bad `?month=` in a URL someone
  # pasted should show this month, not a 500.
  def month_param
    Date.parse(params[:month].to_s)
  rescue Date::Error, TypeError
    Date.current
  end
end
```

```erb
<%= render(Shadcn::EventCalendar::Component.new(
      month: @month.date,
      selected: params[:day],
      events: @appointments.map { |appointment| calendar_event(appointment) },

      # ‹ and › become links: the server answers with the month, and the browser
      # is handed only what it can show.
      month_url: ->(date) { calendar_path(month: date.strftime("%Y-%m")) },

      # The cell becomes a link and the built-in agenda is the frame it swaps.
      day_url: ->(date) { calendar_day_path(date) },
      day_attributes: { data: { turbo_frame: "day" } },
      agenda_as: :"turbo-frame", agenda_attributes: { id: "day" }
    )) %>
```

The mapping is the part a host writes, and it belongs in a helper rather than on
the model:

```ruby
def calendar_event(appointment)
  { id: appointment.id,
    title: appointment.client.name,
    starts_at: appointment.starts_at,
    ends_at: appointment.ends_at,
    color: appointment.service.calendar_color,
    assignees: appointment.assignees.map(&:full_name) }
end
```

**The component never sees a record.** Six fields of ten make the trip; where it
is, who to ring, what state it is in and the note from last time stay on the
model and appear when a day is opened. That is the whole of `day_url:`.

**`includes` is not a detail.** A component may not query — there is a linter
that raises on it — so every `appointment.assignees` inside that `map` is a
query the host issued. On a dense grid it is hundreds.

**`selected: params[:day]`** is what makes a day's URL shareable. Without it the
calendar picks today when the month contains it, and the first of the month
otherwise.

### The `month-change` variant, and what it costs

No `month_url:`. The arrows stay buttons, the controller redraws the month from
what it already has, and *then* announces:

```erb
<div data-controller="calendar-loader"
     data-action="shadcn--event-calendar:month-change->calendar-loader#load">
  <%= render(Shadcn::EventCalendar::Component.new(
        month: @month.date,
        events: @appointments.map { |appointment| calendar_event(appointment) }
      )) %>
</div>
```

```js
// app/javascript/controllers/calendar_loader_controller.js
import { Controller } from "@hotwired/stimulus"
import { visit } from "@hotwired/turbo"

export default class extends Controller {
  load({ detail: { month } }) {
    visit(`/calendar?month=${month.slice(0, 7)}`, { frame: "calendar" })
  }
}
```

The application controller is the one above, unchanged.

**The order inside `goTo` decides the experience**, and it is not visible from
the host's side:

```js
this.monthValue = iso(first)
this.render()                    // draws from what the browser holds
this.dispatch("month-change", …) // and only then says so
```

So the browser paints the new month with the events it has, and the server's
answer replaces it afterwards. With one month loaded that is an empty month and
then a full one — a flash. It cannot be turned off from outside: `client_drawn?`
is a method, `false` only on the readings the server draws whole, not an
argument a host can pass.

**Which is exactly why preloading a window exists.** Load the month either side
and the intermediate draw is *correct*, so the swap is invisible; the flash
returns only when someone steps past the window.

```ruby
grid = (@month.days.first - 1.month).beginning_of_day..(@month.days.last + 1.month).end_of_day
```

| | |
|---|---|
| **`month_url:`** | the ordinary case. No JavaScript, no flash, the browser is handed only the month it shows, and without JS the link still works |
| **`month-change`** | when the page around it must not reload — filters, a map beside it, state living in the DOM — and you will preload a window to avoid the flash |

## A person's preferred view

A person reaches the calendar from the same link every time and wants it the
way they left it. The panel answers "show me this now"; nothing answered "show
me this every time". `preferences:` adds the answer: a last item in the panel,
*Preferences*, that opens a `Dialog` asking the panel's own questions, in the
panel's order, starting from what is on screen. Changing the period re-asks the
questions under it, as the panel does. *Save* keeps the answers and goes there
at once; *Cancel* and Escape change nothing, and the next open starts again
from what is drawn.

Off unless asked, because it adds a menu item, a dialog and browser storage to
a page that did not ask for them. Only the readings with a panel draw it.

### The dialog

The questions, their answers, and when each is asked. All of it comes from one
table in `EventCalendar::Preferences`; the browser only reads the
`data-preferences-when` tokens the server wrote, so it knows nothing about which
question follows which.

| question | answers | asked when |
|---|---|---|
| `period` | Monthly · Weekly · Daily | always |
| `view` | Grid · Rows · Timeline for a month; Rows · Timeline for a week | the period is Monthly or Weekly. Its heading follows the period ("Show the month as" / "Show the week as") and so does the group's `aria-labelledby` |
| `showing` | Timeline only · List only · Timeline and list | the period is Daily. *List only* only when the day has an agenda |
| `group` | By event · By assignee | the view groups: grid, rows, the day |
| `shape` | the host's `shapes:` | the view has an axis and `shapes:` offers more than one |
| `max_chips` | *At most* [a number from 1 to 99] · All | the view caps its chips: grid, rows |

Twenty complete sets in all, with both shapes and an agenda, not counting the
chip limit: a typed number multiplies nothing, so `Preferences#sets` leaves
`max_chips` out (`Preferences::FREE`) and `#asks?(:max_chips, set)` says which
sets take one.

A question that stops applying is hidden and its fields disabled, so it is never
sent. Where the answer it held is no longer offered — *Grid* when the period
becomes Weekly — the first offered one is checked instead, so the dialog cannot
save a set no reading draws.

The chip limit is the person's: how many jobs a capped cell shows before its
"+N". It is two radios. *At most* has a number field beside it
(`type="number"`, `min=1 max=99 step=1`, `required`), and *All* is the
toolbar's *Show all* kept for next time, so the dialog asks one question where
it used to ask "show all, yes or no". The field starts at the reading's own
`max_chips` (3 by default), and *All* is checked when the reading draws
`show_all: true`. A `max_chips:` above 99 starts the field at 99; the reading
still draws the limit it was given.

Both answers share the name `preferences[max_chips]`, and only the chosen one is
enabled: the radio group's hidden input submits `"all"`, the field submits the
number. The form sends one value, never both, and the controller keeps it so as
the answers change (`limitPreferences`). A number outside the range, or none,
stops the submit in the browser, through the field's own constraints.

The radio and the field are both named by one label, `aria-labelledby` its
id, so `getByRole("spinbutton", { name: "At most" })` finds the field. The
copy is `event_calendar.preferences.max_chips` for the question,
`max_chips_number` ("At most") and `max_chips_all` ("All").

`Preferences::MAX_CHIPS_RANGE` (`1..99`) is the range, public so a host
checking the limit in its own URLs uses the same numbers. `#normalize` accepts
`"all"` or a whole number in it, as a string or an Integer, and returns `nil`,
as it does for an unknown period, for anything else: `"0"`, `"100"`, `"4.5"`,
`"abc"`, `""`. A limit that is not given at all is the default, 3. It used to
put an unknown limit back to 3 without saying so.

It replaced a `show_all` question whose first cut listed the options with
`filter_map`, which dropped `false`, and built the label key from the boolean,
`show_all_true`, which no locale has: one option, reading "Translation
missing". The snapshot had recorded that text as correct, so `snapshot_spec`
now fails any golden that renders a missing translation.

Six questions are taller than a short window, and a dialog with no limit put
*Save* off-screen. The panel stops at the window
(`max-h-[calc(100dvh-2rem)]`), and the questions scroll between a header and
footer that stay put, as the dialog's own *Scrollable Content* preview does:
two grid rows, the form being the one that gives (`minmax(0,1fr)`), and a body
that is `overflow-y-auto` with `-m-1 p-1` so the radios' focus ring is not
clipped. Measured at 440px tall: the questions scroll, *Save* stays in view.

Every id in the dialog is `shadcn-event-calendar-preferences-<hex>-…`, one hex
per calendar, so two calendars on a page do not label each other's radios.

### Two homes, and the developer picks

Where the answers live is a property of the host, not a setting in the dialog.

**`:local`** — the gem keeps them in `localStorage`. The host gives
`preferences_url:`, a callable that turns one complete set into the URL that
draws it, and the gem calls it for every set it offers and ships the map in the
markup, 26 entries. The browser cannot run the host's Ruby, and a URL template
with placeholders would break a host's lambda that looks a value up.
Save writes the set and navigates to its URL.

The typed chip limit is the exception, because a number cannot be listed. Each
of the six sets that ask it gets two entries: one for `"all"`, and one keyed
with `#` in the number's place whose value is the URL cut in two where the
number goes. The gem finds the cut by calling the lambda with 23 and with 45 and
comparing the URLs. If the two are the same, the number never reaches the URL
and the entry is that one URL. A lambda that writes the number twice or changes
it has nowhere to put a typed one, and the gem raises `ArgumentError` at render
time instead of sending the person somewhere else. A value from a list is still
never passed as a placeholder, only the number.

**`:host`** — the dialog is a plain `<form method="post">` to
`preferences_save_url:` with `_method=patch`, built with the gem's form
builder so the authenticity token is in it, fields named `preferences[period]`,
`preferences[view]`, `preferences[showing]`, `preferences[group]`,
`preferences[shape]`, `preferences[max_chips]` — only the ones the chosen view
asks; the rest are disabled and not sent. The host saves and redirects back to
its calendar, rendered from what it saved. Under Turbo that is a fetch and a
followed redirect, without it an ordinary submit, and a failure is answered as
the host answers any form. The gem names neither. Gestart's side:

```ruby
def update
  current_user.update!(calendar_preferences: params.expect(preferences: %i[period view group shape showing max_chips]))
  redirect_to calendar_path, status: :see_other
end
```

Validate the values against the table above before saving: they come from
the browser. Only the fields of the chosen view arrive, as strings
(`max_chips` is the typed number, `"7"`, or `"all"`, one of the two and never
both; `show_all` is not sent). `Preferences.new(shapes:, agenda:).normalize(params[:preferences])`
is that check: `nil` means the set is not one the dialog can produce.

Reading them back is also the host's. Its order is the request's parameters,
then the person's saved set, then its own defaults, and the saved set applies
only to the bare arrival, the request with no `period`. The set becomes the
component's arguments like this, for a host whose month grid is the workload
reading:

| saved | arguments |
|---|---|
| monthly · grid | `reading: :workload`, `group:`, and from `max_chips`: `"all"` → `show_all: true`, a number → `max_chips:` it and `show_all: false` |
| monthly · rows | the same, with `arrangement: :rows` |
| monthly · hours | `reading: :hours`, `shape:` |
| weekly · rows | `reading: :weekly, arrangement: :rows`, `group:`, and the chip limit as for the month |
| weekly · hours | `reading: :weekly`, `shape:` |
| daily | `reading: :daily`, `showing:`, `group:`, `shape:` |

The rule that every URL the calendar is handed must carry `period` (below,
under `restore:`) holds here too, for the same reason: a URL without it is read
as the bare arrival and drawn from the saved set.

The dummy app's `CalendarController#save_preferences` is the same shape,
keeping the set in the session; the `:host` system example posts to it.

> Host note: the preferences dialog is not portalled, so a calendar with
> `preferences:` must not be rendered inside a host `<form>`: the HTML parser
> drops the nested form and Save would submit the host's form.

### `restore:`, and why the gem does not guess

In `:local` mode the host says when a request is the bare arrival — the usual
link, no view named. For Gestart that is `restore: params[:period].blank?`:
every set carries a `period`, and a bare arrival carries none. With
`restore: true` and a stored set that differs from what was drawn, the
controller goes there on connect with `location.replace`. Without it, the
controller never moves the page.

The gem guessing instead — marking its own clicks in `sessionStorage` — was
rejected: `connect` also fires on back and forward, when a host swaps the
calendar after `month-change`, and after a host navigates in answer to a panel
event, and each of those would have been pulled away from what the person had
just chosen. The cost, said plainly: one line for the host, and on a bare
arrival the default view shows for a moment before the saved one loads.

`preferences_url:` must draw exactly the set it is given. A URL that drops a
key, or an action that ignores one, lands on a page drawing another set, and
with `restore:` true there too it would ask again on every load. The
controller marks each attempt in `sessionStorage` before it navigates — its
own redirect, not a person's click, so this is not the guess rejected above —
and arriving with the mark still set spends it instead of redirecting again:
a wrong URL costs one wasted redirect, not a loop. Where `sessionStorage`
refuses, restore does not navigate at all.

Restore does nothing when the stored set is the one already drawn (it would
reload forever), when the map has no URL for it (the host narrowed `shapes:`
or turned `agenda:` off after the person saved — a guessed URL could be
anything), or when the browser refuses storage. Save, in a browser that
refuses, still goes where it says; the answer is only not remembered.

Every URL the host hands the calendar must carry `period` (or whatever key its
restore test reads): `month_url:`, `day_url:`, `view_url:`, the `*_url:` menus,
a redirect after `month-change`. One that omits it looks like a bare arrival, so
with `restore: params[:period].blank?` pressing › on a month would take the
person straight back to their saved view.

`restore:` means nothing in `:host` mode, where the host has already rendered
from its own stored set.

### The storage key

`shadcn--event-calendar:preferences:<id>`, with the root's `id` when the host
gives one and `default` otherwise — so two calendars in one app are told apart
by giving them ids. The value is the set as `Preferences.key` spells it,
`preferences[period]=weekly&preferences[view]=rows&…`, which the controller
rebuilds from the form's `FormData`, keeping only the `preferences[…]` fields.

### What is not saved

The month shown and the day selected: the calendar opens on today, as it did.
`window:` and `max_events:`, which are the developer's. There is no "reset to
defaults"; saving other answers replaces the set. `:local` does not follow a
person across devices — that is what `:host` is for. And the panel is
unchanged: a choice made there is for now, and does not touch the saved set.

### Known gaps

- **Cancel resets only the questions that apply.** A hidden question keeps the
  answer chosen before the Cancel, so choosing Daily → *List only*, cancelling,
  and choosing Daily again shows *List only* checked rather than the drawn
  default. Nothing wrong is saved.
- **The `:host` example proves the token is sent, not that it verifies.**
  Lookbook renders a preview inside a nested controller whose session never
  reaches the browser, so the dummy skips verification on that one action. The
  token comes from a standard `form_with`; a host's own system spec is where it
  is checked end to end.
- **The chip limit's error is the browser's.** A number outside 1–99, or an
  empty field, is stopped by the field's own `min`, `max`, `step` and
  `required`, so the bubble that says why is written by the browser, in the
  browser's language rather than the app's locale, and styled by it. The
  server-side check is `Preferences#normalize` returning `nil`, which in
  `:host` mode is the host's to answer.
- **A stale mark after a wrong `preferences_url:`.** When the wrong URL lands on
  a page with `restore:` false, the one-shot mark stays, and the next bare
  arrival in that tab spends it instead of restoring. One skipped restore, only
  for a host whose URL is already wrong.

## Not done

Named rather than left to be discovered:

- **splitting the controller.** Roughly 308 of its lines are the redraw, which
  three of the four readings never run. That much is true and it is where this
  entry used to stop — but "so it is downloaded and unused" was measured
  afterwards and does not follow: `shadcn/index.js` imports all thirty-three
  controllers eagerly, because a host registers them with one call. A second
  controller would be imported there too, and splitting moves none of the 208 KB
  a host gets whichever components it uses.

  The byte question needs nothing built: `CONTROLLERS` is already exported and
  `pin_all_from` already pins every controller individually, so a host that
  wants a subset imports them by path and skips `index.js`. Registering is not
  loading — importing the map pulls every module in either way, because those
  imports are static.

  "Readability and nothing else" is where this entry stopped next, and that was
  a guess too. The split has since been **built and thrown away**, and what it
  cost is in [the todo](../todo.md): the frame depends on the drawing rather
  than the other way round, so the base needs three hooks and all three would be
  dead; `stimulus_contract_spec` goes blind on 35 examples until taught to
  follow a base class; and the premise was false, because `calendar_controller.js`
  is longer and unsplit. What was done instead is the part that was actually
  worth having — the methods are in the order of the two halves, with the four
  edges that cross the seam named at it. The trigger for revisiting used to be
  the week view, on the assumption that it would need a `render` of its own. It
  did not: the week is drawn by the server and the controller returns before
  reaching it. The trigger is a second reading drawn *in the browser*, which
  none has needed yet.
- **the week's agenda, and a week cut by operator.** The week is built — see
  *The period, the week and the day* — without either; both are named in
  [its design](../specs/2026-08-31-event-calendar-week-view-design.md#not-in-this-design)
  as separate pieces.
- **the desktop month's second click.** With events opening from the day's
  list, the month goes from one click to two: the day, then the row. A product
  owner is deciding whether that is acceptable; the week and the day are not in
  question. If it is refused the month alone is revisited
  ([todo](../todo.md#smaller-things)).
- **drag to resize.** Moving is built — see *Moving an event* above — and this
  is the gesture that did not come with it: a second handle on the end of a bar,
  and a rule for what a resize means to a `to` that is inclusive here and
  exclusive in FullCalendar. The machinery it would need already exists.
- **a "+2 more" popover.** The agenda already shows everything on the day, the
  dense reading shows every event without opening anything, and a second way in
  would cost the one-tap-target-per-day property both depend on.
- **letting a host force one reading or the other.** `DENSE_ABOVE` is a constant,
  not an argument, until somebody wants the other side of it — a `labelled:`
  keyword is four lines the day it is asked for.
- **fetching a month's events on demand.** The component dispatches
  `month-change` and takes a `month_url:`, and stops there; doing the fetch
  itself would mean owning a URL convention, which is the host's.
- **rebuilding a workload cell in the browser.** See *Three readings* — the data
  it would need is the data that should not travel.
- **arrow keys that clamp to a range.** The grid moves by day, week, month and
  to the ends of a week, and steps off its own edge into the neighbouring month.
  `Calendar` also has a year jump and `start_month`/`end_month` bounds; neither
  is here because neither argument is.
- **recurrence.** `Event` takes concrete dates. Expanding a rule into occurrences
  is the host's job, and it is the job an `ice_cube` already does.
- **time zones beyond the application's.** Times are formatted by `I18n.l` in
  `Time.zone`, like every other date in this gem.
