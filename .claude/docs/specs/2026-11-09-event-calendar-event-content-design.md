# Event calendar: what an event says, and where it opens

**Status:** agreed in conversation, 2026-11-09. Feeds an implementation plan;
not itself a plan.
**Follows** [the week](2026-08-31-event-calendar-week-view-design.md), whose
*Not in this design* named the week's list as the second piece. It is that piece
— reshaped by the first host that needs it.

**The question:** a host — Gestart is the first — needs an event to say more
than a title, a time and its people, to carry the host's own colour, and to open
somewhere the host decides: a drawer for some kinds of event, a page for others.
How much of that belongs to a library that has to stay generic, and where does
the click land when the thing drawn on the timeline sits inside a day that is
already a click target?

## Intent

The gem draws the **envelope** of an event — where it sits in the day, how long
it is, its order, its mark — and a fixed set of **generic** things inside it. The
host decides what those things mean and where an event opens. Nothing in the gem
knows what an intervention, a signature or a customer is.

**Anti-goals** — it fails even if it works when:

- a field with a Gestart name, or Gestart semantics, reaches `Event`;
- a host that passes none of the new keywords sees any change at all — the gem
  is published, and the goldens are what prove this (see *Testing*);
- the client emits an id, a type or anything else for the host to listen to. What
  a click shows is the server's.

## Decisions

### `Event` gains generic fields, all optional

| keyword | type | drawn as |
|---|---|---|
| `subtitle:` | String | a second line of text |
| `description:` | String | text under the title |
| `done:` | Boolean | a check icon |
| `attachment:` | Boolean | a paperclip icon |
| `attributes:` | Hash | merged onto the event's list row — see *The click* |
| an assignee's `status:` | Symbol | an `Avatar::Badge` on that assignee's avatar |

Already there and unchanged: the start time, `title:` and `url:` everywhere, and
— **on the chip only** — the assignees' avatars and the `+N` past
`AVATARS_CAP` (`Chips#chip_avatars`). The list rows have no avatars today: an
agenda row is a mark, a title and a time line.

The host chooses what goes in `title` and `subtitle`; the gem gives them an order
— title, subtitle, description — and no meaning. `attachment:` is one boolean:
whether the attachment belongs to the record or to something under it is the
host's to collapse. The assignee `status:` is a small fixed vocabulary the gem
styles — **the builder settles the set** (two values, `:done` and `:pending`, is
the starting point; nil draws no badge). It is generic on purpose: in Gestart it
will mean "has signed", and the gem never says so.

`Assignee` is a `Struct.new(:name, :image)` today and is built from a String or
a Hash; `status` joins it as a third member that a String leaves nil.

**The alternative rejected first** was an empty slot per event that the host
fills with its own markup, told whether it is drawing a chip or a list row. It
was dropped as the more complex road: the events reading is drawn in the browser
by cloning templates, so host markup would have to travel to the client per
event, and the bars of `shape: :bars` and the workload's per-operator chips have
no room or no single event to put it in. Generic fields drawn by the gem cost
none of that.

### Where each field is drawn

The **list row** is as wide as the page and shows everything in full —
**including the assignees' avatars, their `status:` badges and the `+N`**, which
it does not draw today. A builder's call, taken because the row is where an event
is read in full, and without it a status would never be visible in the month or
in any list. It is the largest single cost here: new `Item` markup on the
server, and for the client-drawn month reading each assignee's name, initials,
image and status in the payload and an avatar shape in the `<template>` — which
is one more reason the month comes last. The
**chip** is narrow — a few tens of pixels at 390px — and summarises.

**Builder's call, as a default:** the chip keeps its current head (time, span,
avatars) and puts title and subtitle on one truncated line, with `done` and
`attachment` as icons in the head; `description` is the row's only. A host's
designer (for Gestart, a later design pass) may redistribute this — the gem
should not make the split hard to change, but this design does not wait for it.

**"The chip" means `Chips#chip_head` and `#chip_text`**, wherever they are
drawn: the hours, week and day readings, and the workload reading grouped *by
event*, whose `item_chip` uses the same two helpers. Including it is the
builder's call taken here: it is the same chip, and excluding it would mean
splitting shared helpers to make one reading say less. The workload grouped *by
assignee* counts people, not events, and is not touched.

`Hours`' `bars` shape has no room for any of it and stays as it is. **The month
events reading's bars** (`event-calendar-event`: a dot, a time, a title) also
stay as they are, on the server and in the clone — the month is where the open
question below sits, and its rows are where an event is read in full.

### The chip stays decoration; the list row is the link

A chip is drawn **inside the day's target**, which is already an `<a>` (with
`day_url:`) or a `<button>`. A link inside either is invalid HTML — nested `<a>`
is split by the parser — and axe reports nested interactive content. One target
per day is also the property the mobile reading is built on, and
`spec/system/event_calendar_spec.rb` ("keeps the day the only thing that can be
clicked") holds it. So the chip is **not** made a link.

An event opens from its **row in the day's list**, which is already an
`<a href=url>` when the event has a `url:` (`component.rb`, the agenda row).

**The condition** — agreed together with this choice — is that every view that
shows events has a list with clickable rows:

- **Month:** a tap on a day leads to that day's list — the agenda under the
  month. It exists. For the server-drawn readings it appears only when the host
  passes `day_url:`, because the server is what redraws the chosen day.
- **Week:** the list of **the selected day**, under the timeline — one day at a
  time, changed by tapping a day, exactly as the month does. Measured on the
  current branch: with `day_url:` the week already renders this list with `<a>`
  rows; without it there is no list. **No `showing:` switch for the week** and no
  seven-section list: both were discussed and set aside for the selected day's
  list, which reuses what exists.
- **Day:** its rows, under `showing: :agenda` or `:both`, as today.

**For the server-drawn readings the list needs `day_url:`** — the month's
hours and workload readings and the week alike, because the server is what draws
the chosen day. Builder's call taken here: this is documented as part of the
contract ("a host that wants events to open passes `day_url:`") rather than
answered with a new list that works without it. Gestart passes it.

Every row opens with **Enter** — it is a link. With `movable:`, **Space**
picks a row up to move it. Today a movable row is an `<li tabindex="0">` around
the `<a>`: two tab stops, one focusable inside another, and Enter on the `<li>`
does nothing. **In scope:** a movable row with a `url:` becomes one tab stop on
which Enter opens and Space picks up. A row without `url:` is unchanged.

### The click

- **No JavaScript event.** No id, no type, nothing for a host to listen to.
- The row's link is `url:`. Without `attributes:` it is a plain link to a page,
  and stays one with JavaScript off.
- `attributes:` on the event is merged onto that link, per event — the
  equivalent of `day_attributes:` for days, but able to differ from one event to
  the next. **Why on the event rather than an `event_attributes:` callable:** the
  `url:` is already on the event, and the two travel together. Precedence is the
  gem's usual: `data-slot` < component defaults < caller; `class` and
  `data-action` concatenate.
- **A drawer** is `attributes: { data: { turbo_frame: "<frame>", action:
  "shadcn--dialog#open" } }`: the click fills a frame inside a Sheet and opens it,
  with no JavaScript of the host's — the mechanism the `panel` preview already
  uses for days.
- **The events reading builds its rows in the browser**, from a payload
  (`component.rb`, the `{ id:, title:, … url: }` hash) and a `<template>` that
  holds both an `<li>` and an `<a>` row. `attributes:` and the new fields have
  to reach that payload, and the clone has to apply them. It is the expensive
  part of this design. The payload is trimmed per key on purpose — "every key is
  paid for two thousand times" — so absent fields must cost nothing.

### Colour

`color:` accepts, besides the six names in `Event::COLORS`, **a host CSS custom
property**, written as its name: `color: "--calendar-assigned-scheduled"`.

- The gem uses it **as `--event-color`, and only as that**: it drives exactly
  what the six fixed colours drive today — the dot, the tick, the agenda mark,
  the crossing rails, the 12% tint behind a chip's text and the `bars` fill. The
  chip is drawn as today — no filled blocks.
- With a host colour the text **stays neutral** (`--foreground`): `--event-ink`
  is not derived from a colour whose contrast the gem cannot know. A yellow
  token as text on a card is the case that fails.
- Dark mode is the host's: it defines the property under `.dark` too.
- The six fixed names behave exactly as now.

What is *not* the gem's: Gestart's seven colours and what they mean (its legend:
operator assigned or not × scheduled or not, reminder, absence, availability),
and renaming its tokens to `assigned-unscheduled`, `assigned-scheduled`,
`unassigned-unscheduled`, `unassigned-scheduled`. That is work in `gestart_fly`.

## Open

- **The month on a desktop goes from one click to two** — the day, then the row.
  Gestart is asking its product owner. If it is refused, the month alone is
  revisited; the week and the day are not. **So the plan builds the week and the
  day first and the month's part last**, and the week and day ship whatever the
  answer is.

## Left to the builder

- The assignee `status:` vocabulary beyond the two-value start, and its badge's
  look — within shadcn's `AvatarBadge` and the gem's colour rules.
- The chip's exact layout of the new fields, within *Where each field is drawn*.
- The i18n keys for the icons' accessible names ("Done", "Has an attachment").
- How an unknown `color:` falls back. Today an unknown name falls back to the
  calendar's colour; a string starting with `--` is the only new shape.

## Testing

- **A Lookbook preview** — a template, so it gets a golden — with two events:
  one whose row opens in a Sheet through `attributes:`, one without attributes
  whose row goes to its page.
- **The goldens of every existing preview must not move outside a
  `<template>`.** None passes a new keyword; a moved golden means something is
  written unconditionally. The one exception, a builder's call taken here: the
  client-drawn reading clones its rows from prototypes in a `<template>`, and the
  prototype row may gain the parts the new fields need. That markup is inert and
  never shown, and making it conditional on the payload would cost complexity
  that has to survive `turbo:morph`. Every changed golden line must sit inside
  the `<template>`.
- Component examples per field, including a String assignee leaving `status`
  nil and an event without `attributes:` rendering the same row as before.
- A system example: Enter on a row with `attributes:` opens the Sheet; on one
  without, it navigates.
- The events reading: a system example that a row built **in the browser**
  carries `attributes:`.
- `reverse_parity_spec`'s `ours` list for any class no vendored TSX has, with its
  reason.
