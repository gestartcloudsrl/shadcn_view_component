# JavaScript decisions

How Radix's behaviour was reimplemented, and which of the obvious approaches
were tried and abandoned.

## Context-only roots emit a `display: contents` wrapper

`Dialog.Root`, `Popover.Root` and `Select.Root` render no DOM in React. Stimulus
needs an element to attach to. The wrapper has no box, so layout is unaffected,
and it gives shadcn's `data-slot="dialog"` — which Radix silently drops —
somewhere to live.

## Nothing is portalled to `document.body`

Moving content out of the controller's element unbinds the Stimulus actions on
close buttons and menu items. Discovered the hard way: the first implementation
*did* portal, and the dialog's own close button stopped working.

## Layers are promoted with the Popover API instead

Not portalling left them vulnerable to stacking contexts — `position: fixed`
escapes overflow clipping but never a stacking context, so a `sticky z-40` header
buries a dropdown. Proved with a failing spec first
(`spec/system/stacking_context_spec.rb`), then fixed with `showPopover()`
(`app/javascript/shadcn/top_layer.js`), which paints above every stacking context
*without* moving the element. Feature-detected, with the old behaviour as
fallback.

A `<dialog>.showModal()` rewrite was considered and dropped: the Popover API
fixed the same problem with far less change.

**The blocker I had feared did not exist.** Exit animations were the reason to
hesitate — and it then turned out they had never played at all, for an unrelated
reason. See below.

## Closing waits for the animation; everything else does not

Closing used to set `hidden` in the same tick as `data-state="closed"`, and
`[data-slot][hidden]` removes the element outright, so no exit keyframe ever got
a frame. Three paths had it: `floating.js#hide`, `dialog_controller#render`, and
`accordion_controller#render` — the third one the todo had missed, because
`animate-accordion-up` is inert for exactly the same reason.

`ExitQueue` in `animation.js` now holds the DOM half of a close until
`element.getAnimations()` settles. The wait covers only presence in the DOM:
`hidden`, unwrapping the content back to its placeholder, `hidePopover()`,
removing the wrapper. Interaction releases at once — the dismiss layer, aria,
focus, the scroll lock — because a layer on its way out must not answer Escape.

`hidden` used to be what took closing content out of the tab order and the
accessibility tree too, in the same tick, and now it does not reach either
until the wait above is over — for the length of a fade, a dismissed dialog
stayed reachable by keyboard and by a screen reader. `element.inert` closes
that gap, set alongside `data-exiting` in `defer` and cleared alongside it in
`flush` and `cancel`. The two are not two spellings of one thing:
`[data-slot][data-exiting]` in `shadcn.css` is a CSS hook that stops most
exiting elements from intercepting clicks, with a deliberate exception for the
accordion's collapsing panel, which stays clickable while it collapses;
`inert` removes an element from the tab order and the accessibility tree, on
every element this queue defers, accordion included, and has no such
exception. They travel together here because both start when an exit is
deferred and end when it is flushed or cancelled, not because one implies the
other.

**Not `animationend`.** It bubbles from descendants, so it needs filtering by
target and name, and it never fires when no animation applies — which forces a
timeout, and that timeout then becomes the *normal* path in a host that has not
loaded this stylesheet. An empty `getAnimations()` list is unambiguous: the
teardown runs synchronously and behaviour is exactly what it was.

**Not every running animation counts.** An `animation-iteration-count: infinite`
animation reports `"running"` and has no end to reach, and caller classes
concatenate onto a component's own, so a host utility carrying one —
`animate-pulse` among them — reaches closing content through supported API.
Measured: an Escaped dialog still in the document five seconds later, `hidden`
never set, `pointer-events: none`, with everything that closes it already run.
The queue filters on the effect's `endTime` being finite rather than on
`playState` alone; if that empties the list the teardown takes the synchronous
branch above, which is right for an element whose only animation is not an exit.
A timeout was rejected as the fix: the constant would be arbitrary, and the layer
would still be stuck for its length.

### The interruptions are the whole problem

Making a synchronous teardown asynchronous opens a window in which the DOM is
half torn down, and each way of interrupting that window was a separate bug. All
three were found in review rather than by a spec, which is the part worth
remembering: the nominal path was right every time.

- **Reopen mid-exit.** The wrapper and placeholder are still in place, so
  `show()` reuses them instead of mounting again — a second `mount()` strands
  the old placeholder and leaves two wrappers. `cancel()` also has to drop the
  pending teardown, or a stale continuation dismounts a layer that is
  legitimately open again. Tooltip makes this the common path, not an edge case.
- **`disconnect()`.** Cannot wait. Turbo may be detaching the element, and a
  continuation would then operate on a subtree that has left the document.
- **A Turbo snapshot.** `cacheSnapshot()` clones the document while handling
  `turbo:before-cache`, well inside an exit's duration, so a layer closed by the
  same `pointerdown` that starts a Drive navigation would be cached mid-exit —
  wrapper, placeholder and `data-exiting` all cloned in. The queue keeps a
  `turbo:before-cache` listener for as long as anything is pending.

A generation token guards the continuations: `cancel()` followed by a fresh
`defer()` in one tick would otherwise let the first continuation flush the
second exit's teardown.

The same window also has to keep behaving like the content is still there, not
just survive being reopened or torn down early. A floating layer keeps
following its anchor while it fades: `reposition()` and `applyPosition()`
guard on `this.mounted`, not `this.open` — the flag stays true from `mount()`
until `dismount()`, so a scroll or resize during the exit still moves the
content instead of leaving it stranded over its old anchor. `hide()` still
flips `this.open` immediately, since that is what interaction (Escape, an
outside click) has to answer to. Radix keeps the content mounted through its
exit animation — `menu.tsx:253` wraps `MenuContentImpl` in `<Presence
present={forceMount || context.open}>` — but whether Popper keeps
repositioning it while mounted is not checkable, since Radix's Popper
implementation is not among the vendored files; continuing to reposition here
is the safer default, not a proven parity claim.

### One thing given up on purpose

**`prefers-reduced-motion` collapses these animations**, which nothing in the
vendored upstream does. The utilities themselves come from `tw-animate-css`,
which is *not* vendored here, so whether it has since grown handling of its own
has not been checked. Taken because this is a library.

It lives inside the `@utility` bodies rather than in a top-level rule, because
the two compiled shapes differ. All nine `animate-out` uses are
variant-prefixed, so the emitted class is literally
`data-[state=closed]:animate-out` and a `.animate-out` selector would match
nothing — but `tooltip/content` applies the bare `animate-in`, which
a `.animate-in` selector *would* have matched. Nesting reaches both without
having to know which is which.

Note what that does *not* change. At `0.01ms` the animation still exists and
its `playState` is `"running"` — measured, closing a popover forced to exactly
that duration — so reduced-motion users take the **deferred** path, not the
synchronous one. Only the duration changes, not the machinery: `data-exiting`
is still set and cleared, the Turbo listener still added and removed. A comment
asserting the opposite was written and had to be corrected; do not reintroduce
it. A duration of *zero* is a different case and does take the synchronous
branch — but zero is what the test harness produces, not what a user with
reduced motion gets; see
[testing](03-testing.md#asserting-on-an-animation).

## Controllers re-sync on `turbo:morph`

Idiomorph rewrites attributes without disconnecting, so `connect()` never runs
again and the DOM silently reverts to the server's state while the controller
keeps stale ids and targets. Measured: the JS-assigned trigger id vanished and
was not reassigned.

The server wins, which is what a refresh means; `data-turbo-permanent` is the
application's escape hatch, not the library's decision.

## Indicators are rendered hidden, not omitted

Radix mounts a checkbox tick only while checked. Rendering it hidden keeps the
markup correct without JavaScript; the controller detaches it on connect to match
Radix exactly.

## The one CSS trap worth remembering

**Cascade layers beat specificity.** The `:where()` reset that neutralises the
Popover API's UA styles was first written unlayered, so it beat every Tailwind
utility no matter how specific and collapsed the dialog overlay to 0×0.
Unlayered author styles outrank layered ones — it belongs in `@layer base`.

**And for `!important`, that order reverses.** A *layered* `!important` beats an
unlayered one, at any specificity. This bit a second time, in the test harness:
the accordion utilities carry `!important` inside `@layer utilities`, so the
`<style>` block `force_animations` injects to make an animation observable could
not touch them. Two examples quietly became coin flips. The helper now sets the
property inline, which is the only thing that outranks a layered `!important`
short of another layer. See [testing](03-testing.md).

The accordion needs that `!important` because its class name doubles as an
`--animate-*` theme key, which arms Tailwind's built-in functional `animate-*`
utility for the same name: it contributes a second `animation:` shorthand to the
same rule, later, resetting the duration the media query set. Dropping the theme
key would only move the collision into any host that defines one of their own,
so the `!important` stays.

The rest of that account — including why the duplicate declaration is *not*
visible in the compiled output and what to look for instead, which cost one
review round to work out — lives in the comment above
`@utility animate-accordion-down` in `shadcn.css`. One copy, because three
would drift.
