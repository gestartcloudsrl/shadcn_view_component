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

One component. `EventCalendar::Component` renders the whole thing; two plain
objects beside it do the thinking, and one Stimulus controller moves it.

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

`Calendar::Month`, `Schedule` and `Event` are not split. `Chips` — what one job
looks like as a chip, and what a day's total looks like as a badge — is a module
the workload and hours readings both include, because hours is not a kind of
workload: it is a third reading that wants the same chip, so what the two differ
in is the axis, not what an intervention looks like.

### One options panel

The toolbar had a control for the view, one for the grouping and one for the
shape, and two of them were always about a view you were not in. It has one
panel: **which view**, then the only question that view has.

| view | its question |
|---|---|
| Grid | group cells by assignee or by event |
| Rows | the same |
| Hours | draw each job as chips or as bars |

`Grid` and `Rows` are the workload reading at its two arrangements and `Hours`
is a different reading; that distinction matters to this port and to nobody
using it, which is why `view_url:` is one callback rather than two. `:grid` is
`arrangement: :auto`, not a third arrangement — below `lg` it is rows anyway,
because forcing seven columns onto a phone is what rows were built to avoid.

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

## Where it diverges from FullCalendar

**`ends_at` is inclusive.** FullCalendar's `end` is exclusive, which is right for
arithmetic and wrong for everyone who has ever typed a date: an event held on the
19th, 20th and 21st is written here as `starts_at: 19th, ends_at: 21st`. This is
the only deliberate divergence in the data model.

**No `+N more` popover, no week/day/list views, no drag, no resize, no
recurrence.** Named here rather than left to be discovered — see *Not done*.

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

The worked example is `event_calendar/with_turbo` in the gallery, and the half a
preview cannot hold — a model, a route, a controller and the frame's own
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

## Not done

Named rather than left to be discovered:

- **a view switcher, and the week and day views behind it.** The toolbar has a
  grouping menu and a Show all toggle but no Month / Week / Day tabs. The day
  view is the one already half-built: the agenda *is* it, which is why `agenda:`
  turns it off rather than deleting it — a host that puts the day somewhere else
  today is not choosing against the tab tomorrow. Week needs a time axis, which
  is a different component's worth of geometry.
- **drag to move, drag to resize.** Both need a write path — a host endpoint, an
  optimistic update, a rollback — which is an application's decision, not a
  library's.
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
