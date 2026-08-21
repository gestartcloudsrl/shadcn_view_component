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

Ordering decides who gets the top lane, and it is FullCalendar's: longest first,
then all-day before timed, then by the clock, then by title so a render is
stable. A bar that crosses the week is more use above the one-day events than
interleaved with them.

It renders nothing, so it is asserted on directly — the same reason
`Calendar::Month` is a plain object.

## Three readings

`reading:` picks between two of them and the busiest day picks between the rest.

| | |
|---|---|
| `:auto` | the month as a list of events — bars when they can be named, marks when they cannot |
| `:workload` | the month as a *measure* — a tinted count per day, and one chip per assignee or per event |

The workload reading is the one that answers "how much, of what, by whom"
rather than "what is on". Its cells are a heat ramp on the count chip and a
column of chips, its toolbar carries a grouping menu and a *Show all* toggle,
and below `lg` it lays the month out as one row per day.

**It is navigated by URL, not by the browser.** Its cells hold crews and titles
that `#portable_events` does not ship, so there is nothing in the browser to
rebuild them from — and shipping them would mean every assignee of every month
travelling to every page, plus a second copy of the cell in JavaScript, for the
one reading whose data is exactly what should not travel. `month_url:` turns the
nav into links; without it the nav announces `month-change` and leaves the DOM
alone. The other two readings redraw in the browser as before.

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

Measured after: **460 KB, 70 ms, 305 avatars, no Stimulus instances.**

What is still paid twice is the grouping: both cuts of a cell are rendered and
the menu hides one, which is what makes switching free. At this density that is
the next thing to look at, and it is the same trade `show_all:` just stopped
making.

## The keyboard

`role="grid"` on the weeks, `role="row"` on each, `role="gridcell"` and
`aria-selected` on each day — the pattern `Calendar` has implemented all along,
and which this component went without for its first iteration: forty-two
tabbable buttons, no arrows, no geometry, and `aria-pressed` announcing every
unselected day as a toggle that is not pressed.

One tab stop for the month; the arrows move within it, `Home`/`End` reach the
ends of a week, and `PageUp`/`PageDown` cross a month — a step off the grid's own
edge navigates, and the tab stop travels with the selection.

The roles describe the seven-column month. Below `lg` the workload reading lays
the same DOM out as one row per day, so what a screen reader reports and what an
eye sees disagree there. That is the price of one tree serving two arrangements,
and it is the trade the Sidebar documents for the same reason.

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
