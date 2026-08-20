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
`shiftMonths`, `addDays` and the `strftime` shim now have one implementation —
two would have been two chances to disagree about what `%-d` means.

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

## Mobile and desktop are two readings

Not one scaled down, and this is the design decision the component is built
around.

| | below `sm` | `sm` and up |
|---|---|---|
| a cell | its number and up to `max_events` dots | `--event-calendar-cell` tall, with the bars in it |
| a multi-day event | a dot on each day it covers | one bar across the columns it covers |
| reading an event | the agenda under the grid | the agenda, as a detail panel |

A 48px-wide cell can hold a title or be legible, and not both — so on a phone it
holds neither and the events are read underneath. The agenda is one mechanism
rather than two: it is the phone's primary surface and the desktop's detail
panel, which is what lets the grid have exactly **one tap target per day** at
every width.

That is also why there is no "+2 more" popover. The bars are `aria-hidden` and
`pointer-events-none`; clicking the day is what shows everything on it.

## Where it diverges from FullCalendar

**`ends_at` is inclusive.** FullCalendar's `end` is exclusive, which is right for
arithmetic and wrong for everyone who has ever typed a date: an event held on the
19th, 20th and 21st is written here as `starts_at: 19th, ends_at: 21st`. This is
the only deliberate divergence in the data model.

**No `+N more` popover, no week/day/list views, no drag, no resize, no
recurrence.** Named here rather than left to be discovered — see *Not done*.

**Colours are a fixed palette**, `:default :blue :green :amber :rose :violet`.
Free-form is not available and could not be: Tailwind never sees a class built at
runtime, and a hex has no answer for the dark palette. Each name resolves to two
custom properties declared once on the root, so an element is recoloured by
setting one `data-color` — which is what keeps the colour table out of the
controller.

The inks are the 800/300 pair rather than the 500 the dot uses, and both halves
were measured rather than chosen: 500 on a 12%-tinted background is around 3:1,
and 700 is **4.41** — under AA by six hundredths, which is exactly what
`accessibility_spec` exists to catch and an eye does not.

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

## Lazy loading, when a host needs it

The events a component was given are the ones the server had, and the month you
navigate to may have others. So navigation dispatches

```js
document.addEventListener("shadcn--event-calendar:month-change", (event) => {
  // event.detail.month === "2026-09-01"
})
```

and choosing a day dispatches `shadcn--event-calendar:select`. Replacing the
component over Turbo in response to the first is the whole of lazy loading here.
Nothing about the default path needs it: a calendar handed an array works with no
server round trip at all.

## Not done

Named rather than left to be discovered:

- **week, day and list views.** The month view is the one this iteration is
  about; the others need a time axis, which is a different component's worth of
  geometry.
- **drag to move, drag to resize.** Both need a write path — a host endpoint, an
  optimistic update, a rollback — which is an application's decision, not a
  library's.
- **a "+2 more" popover.** The agenda already shows everything on the day, and
  adding a second way in would cost the one-tap-target-per-day property that the
  mobile reading depends on.
- **recurrence.** `Event` takes concrete dates. Expanding a rule into occurrences
  is the host's job, and it is the job an `ice_cube` already does.
- **time zones beyond the application's.** Times are formatted by `I18n.l` in
  `Time.zone`, like every other date in this gem.
