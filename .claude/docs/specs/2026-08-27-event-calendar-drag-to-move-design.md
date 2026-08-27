# Event calendar: moving an event

**Status:** agreed, 2026-08-27. Feeds an implementation plan; not itself a plan.

**The question:** `features/event-calendar.md` listed drag-to-move under *Not
done*, blocked on a write path an application owns. A throwaway spike says the
write path is the easy half. What actually blocks it, and what shape does the
feature take once those are answered?

Everything below marked *measured* comes from that spike — branch
`spike/drag-to-move`, `spec/system/drag_spike_spec.rb`. Everything not marked is
an argument, and says so.

## What the spike answered

**The write path is not the hard part.** Dispatching and letting the host save
works under a hand-written `fetch`, under a Turbo Stream and under a morph
refresh; the host's own controller never had to know anything the component
could not tell it.

**But a morph refresh is not the rollback**, which is where the first version of
this design was wrong. An optimistic move that mutates `this.events` never
touches the `data-…-events-value` attribute, so a morph — which reconciles the
DOM — reaches the controller only when the server's payload *differs* from the
one the page already had. A refusal, by definition, sends back exactly that
payload: no attribute change, no `eventsValueChanged`, and the browser goes on
drawing the move the server threw away. Measured: server `2026-08-11`,
controller `2026-08-10`, chip on the 10th.

**The bars cannot hold a focus.** `component.rb:911` renders the segments layer
`aria-hidden="true"`, because the agenda reads the day out in full and that is
what earns the layer the right to be decoration. A tab stop on a chip is an
`aria-hidden-focus` violation rather than a design choice.

**The agenda can.** There an event is a discrete row, so a pick is unambiguous
by construction rather than by convention — and a crossing event is *one* row
there, which dissolves the "which object did you grab" question for the keyboard
entirely.

**A crossing event is one bar per week**, not one chip per day: the "five chips
in five cells" belongs to the workload reading. Measured: a 4–8 August event
drew a single bar over five columns, and became two only when a move pushed it
across a Sunday.

**Making the whole chip grabbable costs the day.** One metre, three shapes, one
page:

| what the pointer can reach | days that lose their centre | share of the cell |
|---|---|---|
| the whole chip | 17 of 27 | 40% |
| a grip on its leading edge | 0 of 27 | 1% |
| nothing (the agenda row only) | 0 of 27 | 0% |

The 17 is not a number in the abstract: three of the spike's own keyboard
examples went red the moment the chips became grabbable, every one of them on
`day(…).click` with `ElementClickInterceptedError`.

## Decisions

### Move only, and only where the month is drawn in the browser

Resize is not in this design. Neither is any reading but the events one — and
that is not a scoping choice but a consequence: the optimistic redraw *is*
`render()`, and `render()` returns on `client_drawn?`. Enabling the workload or
the hours readings would mean shipping the payload
`features/event-calendar.md` says must not travel.

### Two hands, and they are different gestures

**The keyboard picks from the agenda.** `Space` on a focused row takes that
event and hands the focus to the selected day; the arrows already move; `Space`
places; `Escape` cancels and puts the focus back on the row it came from.

The shift is relative to **the day the agenda is showing** — which is the day the
focus lands on, so the distance the arrows travel is the distance the event
travels. This said "relative to the event's own start, because the agenda is not
on the grid and has no day to be relative to", and that was wrong twice over:
the agenda *is* a day's, and the rule it gave made one press of → move a 19–21
event to 21–23. Caught by the example asserting it.

**The pointer drags a grip on the chip's leading edge.** The chip stays
`pointer-events-none`; the grip alone takes the pointer, and the layer stays
through, so the gaps between bars still belong to the day. The shift is relative
to *the bar*: a two-week event has two grips, and the second one takes hold of
its own Monday. Measured: 7–11 grabbed by the second grip and dropped on the
11th becomes 8–12, +1.

Both hands then follow one rule — *shift by how far you moved from where you
took hold* — and differ only in what "where you took hold" can mean. A grip is a
day on the grid; a row is the day whose agenda it is. The one thing a row cannot
express is taking hold of an event by a day other than the selected one.

The agenda row grows a grip of its own, so the same gesture is available where
the row is — for an event whose bars are off screen. It is relative to the
agenda's day, like the keyboard.

**That grip needs somewhere to live, and the row has nowhere.** The row is an
`Item` written out by hand — a media, a content, a title and a description — so
the prerequisite is to make it one: `Item::Content`, `Item::Title` and
`Item::Description` inside `Item::Component`, with the grip as the bar it leads
with, carrying the colour the dot used to. Built on the spike, and it is a
**host-visible change**: `event-calendar-agenda-mark` goes, and the title and
the meta become `item-title` and `item-description`. It is separable from the
drag and deserves its own decision rather than arriving inside one.

### The value is the source of truth

A move assigns `this.eventsValue` rather than mutating `this.events` behind it.
This is what makes the morph correct without the host's help: the attribute
changes, so a morph delivering the *original* payload is a change, the
`eventsValueChanged` callback fires, and the server's refusal lands by itself.

`revert()` still travels in the event's detail, for the host that answers a
refusal with a toast alone and never re-renders the calendar.

**What this costs was measured rather than assumed**, because re-serialising the
payload on every move is not obviously free on a month that can hold two
thousand events — the duplication inside `#portable_events` measured 117 ms of a
155 ms render before it was fixed.

It is free. One move's whole round trip — build the new array, `JSON.stringify`,
write the attribute, read it back, `JSON.parse` — averaged over 50 runs in
headless Chrome: **1.08 ms at two thousand events**, 0.14 ms at two hundred.
Under a frame, and two orders below the render it triggers. The fallback that
was held in reserve — writing back only the moved event's two dates — is not
needed and is not built.

### `movable: true`, and the gem stops at a `CustomEvent`

Off by default. A host that wires no listener would otherwise get chips that
move and never save, which to a person is indistinguishable from losing data.

The component dispatches `event-move` with `{ id, from, to, revert }` and does
nothing else. No `move_url:` — `month_url:` is not a precedent for one, because
that lambda exists to *draw an `<a href>`* on the server and a drag has no
no-JavaScript form for a URL to serve. Owning a URL convention, a verb and a
payload shape inside the gem is the thing this library does not do.

### An event needs an identity on both sides, and today it has none

`Event#id` is `nil` unless the host passed one (`event.rb:47`) — it exists for
`portable_events` and nothing has needed it since. A move without one dispatches
`id: null`, which the host cannot act on.

So `movable: true` **requires** an id on every event, and raises at render when
one is missing, naming the event's title. A library that let this through would
turn a host's omission into a silent no-op inside a `CustomEvent` — the failure
would surface as "dragging does nothing", days later, in someone else's code.

`data-event-id` then goes on the chip and on the agenda row, written by the Ruby
*and* by the controller. A JS-only attribute is gone at the first morph, because
the server wins.

### Pending is state on the event, not a class on the node

`pending` lives on the event object and is drawn as `data-pending`, which the
Ruby styles with a `data-[…]:` variant — the controller has no classes of its
own. It clears when the server's payload lands, which with the value as the
source of truth happens by itself.

### Something has to say what happened

The agenda's `aria-live` announces the day's list changing, which is a side
effect of a move and not a message about one. Picking, moving and being put back
each need saying, in the region that already exists.

## The contract the controller expects

```
event-move detail:
  id      the event's own id, as the host gave it
  from    the new start, ISO, inclusive
  to      the new end, ISO, inclusive — see the ends_at divergence
  revert  a function restoring both, and redrawing
```

A host listens, saves, and either does nothing (the morph or its own re-render
carries the truth back) or calls `revert()`.

## Known holes, stated rather than solved

- **A drop onto a full day draws nothing.** `weekElement` draws only
  `lane <= max_events`, so an event dropped on a day already at the cap joins
  the "+N more" and disappears. The move succeeds and is invisible.
- **A morph resets the selection** to whatever the server rendered. Measured:
  chosen `2026-08-04`, after the morph `2026-08-03`, and the agenda with it. A
  host doing morph refreshes has to round-trip the selected day or live with the
  snap.
- **Touch at `sm` and above is unmeasured.** Below `sm` the bar layer is
  `display: none` and there is nothing to grab — measured, 0 grabbable chips —
  so a phone is not the question. A tablet at ≥640 CSS px shows bars and has a
  finger, and that is where the `touch-action` trap the Drawer documents would
  arise. Nobody has run it.
- **The grip is 8×22 px**, under the 24×24 that WCAG 2.2's Target Size
  (Minimum) asks for. The argument for shipping it is the "equivalent control"
  exception — the agenda row's grip is larger and the keyboard path does the
  same job — and it is an argument, not a measurement.

## Testing

- `system/event_calendar_spec.rb` for both hands end to end, including the
  refusal: the chip must go back, which is the case a morph alone does not
  carry.
- `stimulus_contract_spec` picks up the new actions and targets for free.
- `reverse_parity_spec` needs an `ours` entry per new class, with its reason —
  and note that it reads the **snapshot goldens** rather than a live render, so
  it stays green on stale fixtures until they are regenerated.
- `system/accessibility_spec.rb` covers the previews; it cannot see a missing
  keyboard equivalent, which is why the keyboard hand is in this design rather
  than after it.
- A preview is what gets any of this into the snapshot, preview and
  accessibility suites at all.

## Not in this design

- **Resize.** A second gesture on the same machinery, and a separate decision.
- **Any reading but the events one.** See above — it is a consequence, not a
  choice.
- **A drop that lands past `max_events` doing something visible.** Named as a
  hole; solving it means either a "+N more" popover, which
  `features/event-calendar.md` rejects for the one-tap-target-per-day property,
  or growing the cell, which changes the month's geometry under a drop.
- **Undo.** The host has `revert()`; a stack of them is an application's.
