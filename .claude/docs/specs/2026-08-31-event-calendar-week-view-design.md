# Event calendar: the week

**Status:** agreed, 2026-08-31. Feeds an implementation plan; not itself a plan.
**The first of three** — see *Not in this design*.

**The question:** the family reads a month three ways and a day one, and
`todo.md` has carried "the week view" as the one shape it does not have. What is
a week here, and what does adding a third period cost a component whose panel
was built for two?

## What a week is

Seven rows, one per day, each an hours axis over the same `window` and therefore
aligned with the others: Tuesday at ten sits directly above Thursday at ten.

This is `Hours::Component` — which already draws one row per day with a
horizontal axis — shown for seven days instead of a month. It was chosen over
the two alternatives, and both are worth naming because the choice is not
obvious:

- **A continuous Monday→Sunday axis**, on which a three-day job is one bar. It
  is the only shape that keeps a crossing event a single object, which is this
  family's distinguishing data model. It comes back in the third piece, where a
  row is a person rather than a day and the axis has to be continuous for that
  to fit on one line.
- **Seven columns with the hours running down**, the shape everyone recognises
  from Google Calendar. Rejected: time has never run vertically here, so it
  reuses none of `day_axis`, the ruler, or the percentage placement, and a
  three-day job goes back to being three blocks.

## Decisions

### `Weekly::Component < Hours::Component`, a sibling of `Daily`

`Daily` already established the pattern: a period that is not the month is a
subclass of the reading it draws with. A week overrides five things —
`period`, `grid`, `title`, `step_button` and `cell_role` — where `Daily`
overrides those plus `scale`, `cell_body`, `agenda?` and its `showing`
plumbing. Everything else, the axis and the placement included, is inherited
untouched.

The two alternatives were a `span: :month | :week` argument on
`Hours::Component` — fewer files, but the title, the nav and the panel would
branch inside a class that is currently one thing — and `Weekly < Daily`, which
has more to undo than to reuse: `Daily`'s nav steps a day, and its `showing` is
the *second* piece, so inheriting from it would make that piece a change to an
inheritance already carrying one.

### The period stops being a boolean

`period_option` decides which period is checked with

```ruby
checked: (name == :daily) == daily?
```

which is a two-value trick, and a third period breaks it. The panel gains a
`period` each reading answers — `:monthly` on the base, `:weekly` and `:daily`
on the two subclasses — and `period_option` compares `name == period`.
`view_options` is drawn when `period == :monthly` rather than `unless daily?`.

This is not incidental tidying: it is the smallest change that lets a third
period exist at all, and it has to happen in this piece whichever way the other
two go.

### The week is the one in the grid that holds `selected`

`Schedule#weeks` already returns the month's weeks with their lanes packed —
per week, which is what makes this cheap. The weekly view takes the one whose
`days` include `selected` and draws its seven rows.

**When `selected` is not in the grid at all, it falls back to the grid's first
week** rather than raising. A host can pass `month: August, selected: 15
September`; `Daily` has the same exposure today and does not say so. The
fallback matches `default_selection`, which answers the same question for a day
by taking the first of the month.

A week that straddles two months is not a special case — the month's grid
already carries the days either side, and a week is seven real days with no
notion of being outside anything.

### An empty day keeps a full row

Measured before it was decided, and it is the one thing looking at it changed.
The rows are ragged — each grows with its lanes — so a week is not seven equal
bands: on the fixture month a row runs from nothing to 185px, typically 84, and
two adjacent empty days ate about 160px of an 802px screen saying nothing.

They keep it. *Thursday is free* is an answer to the question a week is asked,
and it deserves the same weight on the page as *Tuesday is full*; a thin strip
would say it in a whisper. The alignment argument does not apply either way —
"Tuesday at ten above Thursday at ten" is horizontal, and row height cannot
disturb it — so this is a choice about emphasis and nothing else.

### The title reads a span, and the nav steps a week

"17 – 23 August 2026", and "31 August – 6 September 2026" when the week crosses
a month. `‹` and `›` move a week; `Today` goes to this one.

### Roles

`role="list"` over seven `listitem`s, as `Daily` does for its one. There is no
grid to describe: the seven-column geometry a `role="grid"` would be reporting
does not exist in this view.

### What it inherits without asking

`Hours::Component#client_drawn?` is `false`, so the week is **drawn by the
server**. Three things follow, and none of them is a decision this design makes:
the nav is links or a dispatch rather than a redraw in the browser; nothing here
is re-packed in JavaScript; and `movable:` does not reach it, because there are
no prototypes to clone and the drag's optimistic redraw *is* `render()`.

`reading_options` comes from `Hours` unchanged, so the panel asks the week the
same one question it asks the monthly timeline: chips or bars — and the default
answer is the one `Hours` gives, `chips`. See *What looking at it settled* for
what the two cost a week, which is not the same as what they cost a month.

## What looking at it settled

The geometry was checked against the running `hours` reading rather than by
building a throwaway `Weekly`: those rows *are* these rows, and a subclass would
have shown the same seven with a different heading. Three things came out of it.

**A week is about one screen.** The five weeks of the fixture month measure 214,
811, 719, 672 and 856 pixels against an 802px viewport — the first and last
short because they are mostly days from the neighbouring months. So the busiest
week overflows a little and the rest fit. That is what makes seven rows a
sensible shape; at three screens it would have been the wrong one.

**The rows are ragged**, which the phrase "seven rows, one per day" does not
convey, and which decided the section above.

**How tall a week is depends on the shape, and by a lot.** The first
measurement above came from a light calendar. Built and measured on a busy one —
ten to twenty-four events a day — the same week is **1565px at `chips` and 577px
at `bars`**, against an 802px viewport: two screens against seven tenths of one.
A row's height follows its *lanes*, so it is concurrency and not count that
decides, and chips are as tall as a title and a crew where a bar is a line.

**The default stays `chips`**, inherited from `Hours` and unchanged — the week
alters nothing about the reading it is drawn with. Recorded here because it is
the number a host needs when the promise the week makes, *all seven at once*,
matters more than what each bar says: `shape:` is an argument and the panel
offers it, so a busy calendar can take the other one without this design
choosing for it.

**An event outside `window` is reached by scrolling the track sideways.** The
track already scrolls horizontally and a week does not change that — but a month
is a page you are scrolling anyway, and a week is one you expect to have taken
in at a glance, so the same behaviour reads worse here. `window` stays exactly
as `Hours` has it, host-settable and unchanged; this is named as a consequence a
host should know about when choosing one, not as something this design fixes.

## Public API

Additive. `READINGS` and `PERIODS` each gain `:weekly`, so the vocabulary handed
to a host's `view_url:` — `PERIODS + VIEWS` — gains one value. Nothing is
renamed and nothing is removed, so no host breaks; but a host that exhaustively
matches on the callback's argument now has a case it has not seen, which is why
this is written down rather than left to be discovered.

The label is **Weekly**, beside *Monthly* and *Daily* — the period menu names
periods, and this one has no history pulling it anywhere else. It is the third
monthly view, not this, that has a label diverging from its key.

## Testing

- A `weekly` preview, which is what puts this into the snapshot, preview and
  accessibility suites at all.
- A component example for the panel with **three** periods, one of them checked
  — the regression the boolean was hiding, and the reason it is a component
  example rather than a system one: it is about what the markup says, not about
  what a click does.
- System examples for stepping a week and for the title when the week crosses a
  month, which is the case a fixture month makes easy to forget.
- A component example for `selected` outside the grid falling back rather than
  raising.

## Not in this design

The week grew three questions in the space of three answers, and building them
together would mean deciding now what will be obvious after looking. So:

- **The seven-day agenda, and `showing`.** The week's list half and the
  three-way switch it shares with the day. The second piece.
- **The assignee geometry.** One row per person over a continuous axis — seven
  `window`s laid end to end rather than 168 hours, so the nights are elided and
  the day boundaries are ticks. The grouping would then change what a row *is*
  and which axis it sits on, which is why it is not a variation on this design
  but a different one. The third piece.
- **Resize, and anything the drag does not already do.** A server-drawn reading
  has no client redraw to be optimistic with.
