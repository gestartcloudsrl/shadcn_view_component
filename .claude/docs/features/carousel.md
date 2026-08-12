# Carousel

*Adapted: 1:1 in markup, driven by the scroll container the markup already is
rather than by embla.*

`carousel.tsx` is built on **embla-carousel**, and this port is not. That is a
measurement rather than a preference. Of embla's 3,170 lines, the shadcn
component reaches for six things:

| | |
|---|---|
| `scrollPrev()` / `scrollNext()` | move one slide |
| `canScrollPrev()` / `canScrollNext()` | whether either button does anything |
| `on("select")` / `on("reInit")` | when to ask those two again |

Everything else in the file is flex markup and two buttons. And the markup is
already a scroll container: `overflow-hidden` makes one — a person cannot drag
it, but `scrollLeft` moves it. Adding `overflow-x: auto` and snap points hands
the dragging, the momentum and where a release lands back to the browser, and
leaves the controller reading one number to answer the two questions and writing
one to move.

The same trade `scroll-area` made: the layout is CSS, and the controller
computes a number per axis.

## What is not ported

- **`opts`** — embla's options. `loop` is the one that will be missed: a
  scroller has ends, and looping means cloning slides and jumping the scroll
  position, which is embla's hardest part rather than a flag.
- **`align`, `slidesToScroll`, `startIndex`, `dragFree`** — the rest of `opts`.
- **`setApi` and the `api` object** — upstream hands the caller embla's
  instance. There is no instance here; what a caller can reach is the Stimulus
  controller, which is not the same shape and is not documented as if it were.
- **Plugins** — autoplay, fade, class names, wheel gestures.
- **Mouse drag.** A finger drags a scroller; a cursor does not. embla
  implements pointer-drag itself and this does not, so on a desktop the buttons
  and the arrow keys are the way through.

None of these has markup, so `parity_spec` cannot see their absence. This file
is where that is written down.

## Two places the port has to say something the TSX does not

**The viewport's scrolling, in `shadcn.css`.** `carousel-content` keeps
upstream's `overflow-hidden` exactly; a rule keyed on its `data-slot` adds
`overflow-x: auto`, the snap type and a hidden scrollbar. That is the shape this
file already uses for `scroll-area`'s viewport, and it keeps the class attribute
byte-identical to upstream's.

**The slide, in CSS rather than in JavaScript.** `scroll-behavior: smooth` is
declared under `prefers-reduced-motion: no-preference`, and the controller
passes no `behavior` at all. Asking for `behavior: "smooth"` from JavaScript
takes the decision away from the browser, and a context that has decided not to
animate can then leave the scroll unstarted rather than instant — measured, in
a Chrome that runs no animation frames: every smooth path was a no-op and every
instant one worked. A carousel that jumps is a working carousel; one that does
nothing is not.

## One attribute upstream does not set

The viewport carries `tabindex="0"`, a `role="group"` and an
`aria-roledescription="slides"`. Upstream sets none of them, and upstream does
not need them: embla translates a track inside a hidden overflow, so there is no
scrollable region for a keyboard to be shut out of. Ours *is* one — that is the
whole mechanism — and axe fails a scrollable region with no keyboard access.
The same divergence, for the same reason, as `scroll-area-viewport`.

It earns its place beyond the audit. Tab now reaches the slides and the arrow
keys move them; before, the only way through the component was its two buttons.

## What moving by one slide means

Not "the current position plus one item's width". The track carries a negative
margin against the items' padding — upstream's own gutter, `-ml-4` against
`pl-4` — so the first slide starts at **-16** and a step of one width lands
between two snap points instead of on one. The controller asks each item where
it is and takes the nearest one past where the scroller stands.

## The keyboard

Upstream binds the arrows on the root with `onKeyDownCapture` (carousel.tsx:119)
and this port uses Stimulus's `:capture` for the same reason: a slide can hold
controls of its own, and one that stops a keydown would take the carousel's
arrows with it. The root takes no focus of its own in either — the keys are
pressed on something inside it.

## What the specs cover

`spec/system/carousel_spec.rb` drives the buttons rather than the controller,
because "the button is disabled" is half the behaviour and a method call cannot
tell you whether a person could have reached it. Seven examples: where it starts,
moving on and back, running out at each end, the arrow keys, that the viewport
is really a snapping scroller, and the vertical axis.
