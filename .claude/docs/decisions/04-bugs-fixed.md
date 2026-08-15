# Bugs found and fixed

Mostly surfaced by a local council review (devil / simplicity / maintainability /
performance). Each was reproduced before being fixed. Kept as a list of things
not to reintroduce.

## Attribute precedence was inverted

What a subclass passed to `super` in `#element_attributes` landed in the
*overrides* slot, so component defaults beat caller props —
`Icon.new("x", width: "16")` rendered `width="24"`. React spreads `{...props}`
last.

Fixed by swapping the merge order in the base class: one line, no churn across
the 79 files that override the method. An `element_defaults` macro was considered
and rejected as more change for the same result.

## `data: { action: … }` emitted the attribute twice

The string spelling was concatenated, the idiomatic Rails hash spelling was not —
invalid HTML, and the browser keeps the first, so the component's own action
never fired. Both spellings are now normalised before merging.

## `crypto.randomUUID()` is secure-context only

Over plain HTTP — a LAN IP, a staging box — it is `undefined`, the controllers
threw on connect, and four families were silently dead. Replaced with a counter;
these ids only need to be unique within one document.

## Escape was swallowed page-wide

`stopPropagation()` on a document *capture* listener meant any open layer, a
tooltip included, ate the key before the host application's own handlers. Now
bubble-phase and non-stopping.

## Floating content came back in the wrong place

`hide()` appended to the container rather than restoring position, so after one
open/close a Select's content sat after its hidden input, permanently. Fixed with
a placeholder comment node.

## The gem did not own `[hidden]`

Closed overlays were being hidden by Tailwind's *preflight*. A host app that
imports Tailwind without it would paint every dialog, sheet, dropdown and select
open on load. Now `[data-slot][hidden]` is the gem's own rule.

## `:root` had drifted from `theme-neutral`

`oklch(0% 0 0)` against `oklch(0.145 0 0)`, so the default look was not the
neutral palette the docs claimed. Now generated from the same JSON by
`rake themes:build`, with a CI gate that fails if regenerating produces a diff.

## Select, Checkbox and Switch had no accessible name

Found by axe, and true **even through the FormBuilder**. They are `<button>`s
carrying an ARIA role, and `role="combobox"` forbids taking the name from
content. (The original note here said `<label for>` cannot name a button. It
can — button is a labelable element — though `ThemeSelector` also names its
trigger with `aria-labelledby` now, to match the FormBuilder; see
[testing](03-testing.md).)
shadcn/Radix have the same gap. The FormBuilder now wires `aria-labelledby`, and
the previews demonstrate it.

**The correction outlived its own correction.** Two previews went on saying a
`<label for>` cannot name a button for months after this entry said it can, and
they had been *written* to work around it. Settled with the accessibility tree
rather than with the spec text: in Chrome, a `<button role="switch">` carrying
nothing but a `<label for>` is named by that label, `relatedElement` and all.
The previews now use it, as upstream's own switch example does. A sentence in a
decision document does not reach the code that already believed otherwise —
`grep` for the claim, not for the file you changed.

## Repositioning forced a synchronous layout per scroll event

`reposition` wrote a transform and immediately read `offsetWidth`, unthrottled,
on `scroll` with capture. Coalesced into one `requestAnimationFrame` — with the
opening placement kept synchronous, or the layer flashes at the top-left for a
frame.

## A closing layer could be cached by Turbo mid-exit

Also introduced while making exit animations play, and also caught in review
rather than by a spec. `turbo_spec.rb:45` already had an example for exactly
this failure and passed vacuously: Capybara zeroes the duration, so the teardown
ran synchronously and there was never an exit in flight to be cached. The
example added *with* the fix, `turbo_spec.rb:78`, forces a 2s duration onto the
select and asserts zero popper wrappers at `turbo:before-render` — that one does
reproduce the bug. Confirmed by commenting out `watchTurbo()`: it fails with
`expected: 0, got: 1`, and the other eight examples in the file stay green.

Once the DOM teardown waits for the animation, a layer closed by the *same*
`pointerdown` that starts a Drive navigation is still in the document when
`cacheSnapshot()` clones the body one tick later. The snapshot then contains the
popper wrapper, the placeholder comment and `data-exiting`. Restoring it gives
you an orphan wrapper, a second one nested inside it the next time the layer
opens, and content stuck at `pointer-events: none`.

`ExitQueue` keeps a `turbo:before-cache` listener for as long as anything is
pending, and drops it when nothing is. One listener per queue rather than one at
module load: most pages never have an exit in flight when they navigate away.

## The backdrop could re-enter the top layer above its own dialog

Introduced while making exit animations play, and caught in review rather than
by a spec — the worst of that batch, because of where it leaves the user.

The overlay carries no `duration-*` class at all: 150ms is the `animate-out`
default. Dialog content is `duration-200`, sheet content `duration-300`. So once
the DOM teardown waits for the animation, the overlay's teardown always runs
*first*, and `hidePopover()` takes it out of the top layer while the content is
still in it.

Reopen inside that window and the overlay's `showPopover()` appends it to the
**top**, while the content's throws `InvalidStateError` — it never stopped
showing — and is swallowed by the `catch` in `top_layer.js`, leaving it in its
older, lower slot. The `bg-black/50` now paints over the dialog and eats its
clicks. Dialog and Sheet let you out on the next click. **AlertDialog does not:
Radix keeps it dismiss-proof on outside clicks on purpose, so the user is left
with a dimmed, unclickable dialog and no way out.**

Fixed by restacking on reopen — `topLayer.hide(element)` before `show()`, but
only for an element that had an exit pending, so a cold open is untouched.
Waiting for both elements together would also have removed the cause, and was
rejected: it holds the overlay painted 150ms past its own animation, which is
the thing separate waits exist to avoid.

The general shape is worth more than the instance. Making a synchronous teardown
asynchronous opens a window in which the DOM is half torn down, and every such
window needs its interruptions enumerated — reopen, `disconnect`, and a Turbo
snapshot each found a different bug in the same change.

## The icon registry relocated its own bug twice before it was fixed

Worth keeping as a shape rather than an incident, because each fix looked like a
fix and moved the failure somewhere rarer and worse.

`Icon` raised on an unknown name, so a typo in a host's template was a 500 on a
decorative element. The registry was added to remove that.

1. **Registry in `app/components`.** That path is reloadable, so the hash was
   discarded on every code reload while the host's initializer ran once at boot.
   The 500 stopped being a typo and became *correct usage, a few minutes in*.
2. **Registry moved to `lib/`.** Reload fixed — but the README still told hosts
   to call `Shadcn::Icon.register` from `config/initializers/`, where no
   autoloadable constant resolves at all. Now the application did not boot.
3. **Documented entry point moved to `ShadcnViewComponent::IconRegistry`**, a
   `lib/` constant required before the engine. Verified by writing the README's
   own snippet into a real initializer, booting, rendering, and reloading.

Both earlier probes used `bin/rails runner`, which runs *after* boot — which is
exactly why neither could see a boot failure. **A check that presupposes the
thing it is checking cannot fail.**

## `bin/setup` raised a `TypeError`

`chdir:` was not a keyword in the `system!` signature, so it reached `system` as
a positional Hash. It survived because nothing ever ran the script — CI did the
steps individually. CI now runs `bin/setup`.

## A cursor moved for a week without colouring anything

Reported as "nothing moves". The cursor moved the whole time — one ArrowDown
took the searchable select from `apple` to `banana`, with `aria-activedescendant`
following it. What never moved was a pixel: the highlighted item's computed
background was `rgba(0, 0, 0, 0)`.

The plain select colours its cursor with `focus:bg-accent`, which works because
the item really *is* focused. Moving to virtual focus so the search field could
keep the caret left the cursor as `data-highlighted` alone — and nothing in this
gem styled that attribute. The whole select family had no `data-[highlighted]`
rule at all. The highlight mechanism was replaced with one that had no styling
behind it.

Fixed by adding `data-[highlighted]:bg-accent` and
`data-[highlighted]:text-accent-foreground` beside the `focus:` pair, so both
modes colour.

**The part worth keeping** is that every instrument agreed it was fine. The
specs asserted `data-highlighted`, the snapshots compared HTML, axe read roles,
and mutation checks proved the attribute moved when it should. All four are
blind to a colour. When a change swaps *how* something is indicated rather than
*whether*, none of them notice — the example that guards it now reads
`getComputedStyle(...).backgroundColor`, which is the only one of these that
could have failed.

## The select's scroll buttons scrolled away with the options

They were markup only for most of this port's life — reproduced because shadcn
emits them, wired to nothing. Connecting them showed why nobody had noticed:
they were also in the wrong element.

Radix scrolls its **viewport**, which carries `position: relative; flex: 1;
overflow: hidden auto` inline (vendor/radix/ui/select.tsx:1240-1247), inside a
content that is `display: flex; flexDirection: column` (:1127-1128), with the
buttons as the viewport's siblings at `flexShrink: 0` (:1691). That is what pins
them to the panel's edges.

This port had no overflow on the viewport at all. The **content** scrolled, and
the buttons rode along inside it: measured on the `scrollable` preview, with the
panel's bottom edge at 387px the down button's bottom sat at 993px — six hundred
pixels past anything visible. It came into view only once the list had reached
its end, which is the one moment it has nothing left to offer.

Fixed by adopting Radix's arrangement: `flex flex-col` on the content, the
overflow and `flex-1` on the viewport, `shrink-0` on the buttons. A searchable
panel moves the scrolling one level further in, onto the list, so its search
field stays put.

Not to reintroduce: no class token moved out of the family, so `parity_spec` had
nothing to say about any of it — the content still carries every class upstream
emits, including the `overflow-y-auto` that is now inert on it, exactly as it is
inert on shadcn's.

## Promotion to the top layer was never undone

`top_layer.enable()` set `popover="manual"` and nothing ever removed it. The UA
gives `[popover]` `position: fixed` whether it is showing or not, so
`hidePopover()` does not put an element back in the page's flow. The reset in
`shadcn.css` neutralises the rest of those defaults — `inset`, `width`, border,
background — and deliberately not `position`, because every caller through
`floating.js` enables it on a wrapper `createWrapper()` already made fixed.

The Sidebar is the first caller to promote an element the page is laid out
*around*. From the first time its mobile sheet opened, the panel stayed out of
flow: `sidebar-gap` reserved nothing and the page was drawn straight over the
desktop sidebar, at every width, for the rest of the session.

Fixed with `top_layer.disable()`, in `closeMobile()`'s deferred teardown —
alongside `hide()`, after the slide-out, since the sheet wants `position: fixed`
for as long as it is on screen.

Not to reintroduce: a second component promoting an in-flow element needs the
same pairing. Promotion is not symmetric with `show`/`hide`.

## The mobile sheet opened onto an empty strip

Two elements hide below `md`, not one — the panel's `hidden … md:block` and
`sidebar-container`'s own `hidden … md:flex`. The controller undid the first and
nothing undid the second, and `md:flex` can only ever switch on *above* the
breakpoint it names, so the sheet's contents had never rendered on a phone.

Fixed with `group-data-[mobile=true]:flex` on the container, plus upstream's
`SIDEBAR_WIDTH_MOBILE` as `--sidebar-width-mobile`.

Not to reintroduce: the system spec asserted the *outer* element was visible and
passed throughout, and the design spec named only the panel's class. Both are
recorded in [03-testing.md](03-testing.md#assert-on-what-a-person-would-see-not-on-the-element-the-flag-lands-on).

## A dismiss layer counted its own backdrop as inside

Upstream portals `sheet-overlay` beside the content, so a click on it is outside.
Nothing is portalled here, so the sidebar's backdrop is a *child* of the panel —
and `pushLayer({ element: sidebar })` then read a click on the backdrop as a
click inside the layer. Tapping the dimmed area stopped closing the sheet.

Fixed by registering the layer on `sidebar-container`, the half that is not the
backdrop: the sibling relationship recovered by choosing a different element
rather than by moving one.

Not to reintroduce: it also cost ten unrelated failures in `overlays_spec` and
`select_spec` that appeared only in a full run, because the layer was never
popped from `dismiss.js`'s shared stack.

## A floating layer did not follow an anchor that resized

`FloatingLayer` positioned on open and then listened for `scroll` and `resize`.
Neither fires when the *anchor* changes size while staying put — and the sidebar
is where that happens: focus a menu row, press `cmd/ctrl+b`, and the button goes
from the panel's width to the icon's under an open tooltip. The label stayed 207
pixels out from the icon it names.

floating-ui does not have this because `autoUpdate` observes the reference
element. `FloatingLayer` now observes its anchor with a `ResizeObserver`, which
fixes it for every popper-based component rather than for the sidebar alone.

## The backdrop reappeared after its own fade

Nothing in the compiled bundle sets `animation-fill-mode` — so an element returns
to its **pre-animation** state the instant its keyframes end. The sheet's overlay
was hidden from the container's `ExitQueue` callback, so `fade-out-0` finished at
150ms, the overlay snapped back to a full `bg-black/50`, and a sheet of grey
glass sat over an emptied page until the panel's `duration-300` ran out.

Fixed by deferring each element on its own animations, which is the rule
`dialog_controller.js` already states for its layers.

Not to reintroduce: "hide it when the close finishes" is only safe where one
element animates. Where two do, the shorter one must not wait for the longer.

## An inline style silently disabled the class it shared a property with

The toaster's `place()` writes where each toast sits, and among the properties it
sets is `opacity` — inline, on every toast, on every pass. The toast's own class
list carries `data-[state=closed]:opacity-0`, which is its exit. An inline style
beats a class, so that exit **never played**: `ExitQueue.defer` asked for the
running animations, found none, and took its synchronous branch, taking the toast
out of the DOM in the same tick it was closed.

Nothing saw it. The snapshot is the markup, not the styles; the system specs run
under a harness that removes transitions outright, so a toast leaving instantly is
what they expect either way (see [03-testing.md](03-testing.md)). It was found by
looking at the page, and it was not what was being looked for.

Fixed by handing the property back — `close()` clears the inline `opacity` before
deferring, so the class decides again.

Not to reintroduce: a controller that writes an inline style takes that property
away from every class on the element, including the component's own state
classes. Before writing one, check what the class list already says about that
property; where both want it, the controller has to yield it back at the moment
the class matters.

## The tooltip's arrow was 10px of intent and 0px of box

Four things were wrong at once, and the component had shipped that way. Reported
by a person opening the docs page beside the gallery, in three rounds, because
each fix revealed the next.

- **An inline `<span>` takes no size.** Upstream's arrow is an `<svg>` — a
  replaced element — so `size-2.5` applies to it and not to the span this port
  rendered. `display: block` on both the wrapper and the square, in a `style`
  attribute rather than a class, because `reverse_parity_spec` would rightly
  object to a class no vendored source carries.
- **Nothing positioned it.** Radix places the arrow through Popper; this one was
  laid out in the text flow after the label.
- **The panel sat flush against its trigger**, because Radix folds the arrow's
  height into the side offset and this did not.
- **One `transform-origin` for four sides** left the left and right arrows spun
  off their own edge.

Not to reintroduce: an arrow is Popper's job, not the component's — see
[02-javascript.md](02-javascript.md). And a `size-*` class on something that is
not a replaced element is a no-op, which no spec here can see: the class is in
the markup, so parity and the snapshot are both green.

## `aria-describedby` named an element that was never rendered

Found while writing up the FormBuilder's divergences from `form.tsx`, and it was
not a divergence at all: upstream has the same shape. `FormControl` set
`aria-describedby` to the description's id unconditionally, so a field with no
description pointed a screen reader at an id nothing in the document carried.

`ShadcnViewComponent::FormBuilder` now records which attributes actually rendered
a description (`form_builder.rb:162`) and names only those.

Not to reintroduce: an id in an ARIA relationship is a promise that the element
exists. And it was believed *not* to be happening here until the page was
checked — the claim came first and the verification contradicted it, with the
broken reference live in the gallery and the whole suite, axe audit included,
green. Why axe let it through was not established, so do not read that audit as
covering dangling references.

## Every pie slice named itself, which ARIA forbids

The first chart gave each `<path>` an `aria-label` and a `tabindex`, so a
keyboard could reach a slice and a screen reader could read it. axe failed it
with `aria-prohibited-attr`: **`aria-label` on a `<path>` with no role names
nothing**, because the element has no role that takes a name.

The fix was not a role per slice. An SVG is one `role="img"`, and everything
inside a `role="img"` is presentational — so the *name* has to carry the data or
the data is gone: "Visitors by browser — Chrome: 275, Safari: 200, …". The
slices are decoration now.

Not to reintroduce: a decorative element that is focusable, or an `aria-*`
attribute on an element whose role cannot take it. And the cost is written down
rather than left implicit — a keyboard user gets the name and not the tooltip,
where upstream's `accessibilityLayer` makes recharts' chart arrow-navigable.

## An SVG `<title>` is a tooltip the browser draws itself

The same chart carried a `<title>` saying exactly what its `aria-label` said —
belt and braces for the accessible name. Chrome renders `<title>` as a native
tooltip after about a second of hover, so the component's own tooltip was
covered by a grey box repeating the whole chart. Reported from a screenshot,
which is the only way it could have been: it appears on dwell, and nothing in
the DOM changes.

`role="img"` plus `aria-label` is the name; the `<title>` was removed.

Not to reintroduce: `<title>` inside an SVG a pointer will hover. It is not
`<title>`'s fault — it is the only element whose *rendered* behaviour differs
from what a DOM assertion sees, which is why no spec here had a chance.
