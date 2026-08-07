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
