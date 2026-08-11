# Drawer

*Adapted: 1:1 in markup, with four of vaul's features deliberately not ported.*

Upstream builds this on **vaul**, and vaul is a Radix Dialog with a drag on top
— `import * as DialogPrimitive from '@radix-ui/react-dialog'` is the third line
of its source. So the open/close half of this component *is* the dialog's and
runs on `shadcn--dialog`: the focus trap, the scroll lock, Escape, the outside
click and the exit animation are already there and none of them is
reimplemented. `shadcn--drawer` is the drag alone, on the content — the same
arrangement the menubar has with the dropdown.

## The two numbers

A release closes the drawer if it was **thrown** — above `0.4 px/ms`, whatever
the distance — or if it was **dragged past a quarter** of the panel, however
slowly. Both are vaul's own constants. Dragging *into* the drawer is
rubber-banded rather than stopped: `8 * (log(v + 1) - 2)`, so 100px of finger
gives back about 20px of panel.

## What is not ported, and what each would cost

| | vaul | Why not |
|---|---|---|
| Snap points | 291 lines | The largest single feature, and none of upstream's own drawer examples use one. |
| Scaling the page behind | 60 lines | Needs a `[data-vaul-drawer-wrapper]` in the *host's* layout, which is the one thing a library cannot put there. |
| iOS `position: fixed` workaround | 145 lines | There is no iOS in this repository's harness. Writing it without running it would be fiction. |
| Nested drawers | ~45 lines | No upstream example shows one. |

A `data-vaul-snap-points="false"` is emitted as a constant rather than dropped,
because vaul's own stylesheet selects on it. The day snap points arrive, those
rules have to stop applying, and a selector that already says so is the
difference between adding a feature and remembering to.

## Two things this port had to take from outside `vendor/shadcn/`

**A third party's attribute name in our markup.** `data-vaul-drawer-direction`
is not ours and not shadcn's, but it is inside the Tailwind class strings this
port reproduces byte for byte — `data-[vaul-drawer-direction=bottom]:rounded-t-lg`
and twenty more like it — so the markup has to speak it. Unlike the Sheet, the
four edges are not cva variants: upstream emits all four sets of classes at
once and lets the attribute choose, so the element carries every one of them.

**A stylesheet.** `drawer.tsx` renders no entrance animation and no
`touch-action`; both are in the 256-line stylesheet vaul's package ships, and
the component does not work without them. `touch-action: none` is load-bearing
rather than decorative — without it the browser claims the vertical gesture,
cancels the pointer stream mid-drag and the panel never moves; five of the nine
system examples fail with that one declaration removed. The part this port uses
is reproduced at the end of `shadcn.css` and the source is vendored at
`vendor/vaul/` so there is something to diff against. `parity_spec` cannot see
any of it: it compares Tailwind class *text*, and a stylesheet rule is not a
class.

## What the specs do not prove

`shouldDrag` decides whether a press inside the drawer means "drag the panel"
or "scroll what is under my finger". Its scroll-climb, the direction
short-circuit above it, and `elementUnder` — which exists only to feed the
climb the right element — **are not exercised by any example here.** Measured
rather than assumed: Chrome cancels a pointer stream that starts inside a
scroll container — whichever way it then travels — and scrolls the container
itself, so the gesture never reaches our code. The end behaviour is right, and
`spec/system/drawer_spec.rb` asserts it; who produces it is the platform.

Both branches stay. They are vaul's, and they are what answers on a platform
that does not step in first — which is every platform this gem will actually
ship to and none that it can be tested on here. See
[testing](../decisions/03-testing.md).

## The one addition: pointer capture

vaul does not capture the pointer, and this port does. It is the only place
here that *adds* rather than leaves out, and it exists because vaul is written
for a device where the browser does the capturing for it.

A touch pointer is implicitly captured by whatever it started on, so on a phone
vaul receives every move and every release however far the finger travels. A
mouse is not, and vaul binds its handlers to the panel — so with a mouse the
gesture is lost the moment the cursor crosses the panel's edge, which a drag
*upwards* does immediately, since the rubber band leaves the pointer above the
panel by design.

Both halves of that were reported from the gallery, one after the other. First:
released outside the panel, the `pointerup` went to whatever was under the
cursor, the drag never ended, and the drawer followed the mouse around the page
with no button held down. Then, after a first fix that ended the drag when the
pointer left: the panel stopped following as soon as the cursor went above it.

The first fix was the wrong one of the two available. Capturing solves both,
and it does not change what the component does — it makes the mouse behave the
way touch already does. What it costs is the target: every captured move
reports the panel, which is exactly what `shouldDrag` climbs from, so
`elementUnder` recovers it with `document.elementFromPoint`.

A `lostpointercapture` handler was written alongside it and then deleted: with
capture in place `pointerup` always arrives, no mutation could distinguish the
handler, and it was the same shape as a piece of machinery the menubar shipped
and then removed for the same reason. `elementUnder` survives that test only
because the branch it feeds is the unreachable one below.

## The exit starts where the finger left it

vaul's `closeDrawer` cancels the drag and does not touch the transform
(`index.tsx:536-549`). That is not an omission: the exit is a CSS animation with
no `from`, so it begins at whatever the element currently reads — which is
exactly where the panel was let go. This port cleared the drag's inline styles
before closing instead, so the panel snapped back to full height for a frame and
slid away from *there*; dragged past the bottom edge it read as the drawer
jumping up before it went. Reported from the gallery.

The styles are cleared on the way back **in** rather than on the way out, which
is what keeps a reopened drawer square. Both halves have their own example, and
each kills only the other's mutation.

Worth knowing for anything else about this component's exit: the suite runs
under `--force-prefers-reduced-motion`, so the reduced-motion rule collapses the
drawer's animation to 0.01ms and the panel is hidden before a spec can read
anything. `force_animations` buys the time back, and without it this defect is
invisible to every example in the file.

## The specs drive touch, not a mouse

Not only because a drawer is a phone component: a touch pointer is *implicitly
captured*, so it exercises the path this port now gives the mouse as well, and
it is the path the release thresholds were tuned on.

Two examples are mouse-driven on purpose, and they are the two that found the
capture bugs above — both were invisible to every touch-driven one, because a
captured pointer can never leave the panel and so can never lose its own
release.
