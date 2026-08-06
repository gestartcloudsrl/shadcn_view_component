# Exit animations

Every `data-[state=closed]:animate-out` class in the port is inert. Closing sets
`hidden` in the same tick that sets `data-state="closed"`, and
`[data-slot][hidden] { display: none !important }` removes the element before a
single frame of the exit keyframes can paint. The markup matches shadcn; the
behaviour does not.

This spec closes that gap.

## Scope

Three closing paths, not the two [todo](../todo.md) records.
The third turned up while reading the code.

| path | components |
|---|---|
| `floating.js#hide` | popover, dropdown menu (and submenu), select, tooltip |
| `dialog_controller#render` | dialog, alert dialog, sheet, and the dialog overlay |
| `accordion_controller#render` | accordion — `animate-accordion-up` is inert for the same reason |

Collapsible runs the same machinery but upstream gives its content no animation
classes, so it has nothing to repair and is left alone.

## Mechanism

`element.getAnimations()`, not `animationend`.

`animationend` bubbles from descendants, so it needs filtering by both `target`
and `animationName`; worse, it never fires at all when no animation applies,
which forces a timeout — and that timeout then becomes the *normal* path in a
host that has not loaded this gem's CSS. A library cannot ship a delay that only
exists because its own stylesheet is missing.

`getAnimations()` asks the browser what is actually running on that element.
Nothing running means nothing to wait for.

```js
// app/javascript/shadcn/animation.js
//
// Resolves once the animations currently running on `element` have finished.
// Returns `null` — not a resolved promise — when there is nothing to wait for,
// so callers can stay synchronous in that case. That matters twice over: it is
// what keeps closing instant in a host that never loaded this stylesheet, and
// it is what keeps the existing system specs from becoming timing-dependent.
//
// No `{ subtree: true }`: only animations targeting the element itself count.
export function whenSettled(element) {
  const running = element.getAnimations().filter((a) => a.playState === "running")

  return running.length ? Promise.all(running.map((a) => a.finished)) : null
}
```

The degenerate cases all collapse to today's behaviour on their own: CSS not
built, host overriding the classes away, `prefers-reduced-motion` — each yields
an empty list and a synchronous close.

## Generation token

Each closing path keeps a counter. `hide()` increments it and captures the
value; the deferred teardown runs only if the counter still matches.

Reopening mid-exit, `disconnect()`, and the `turbo:morph` re-sync all increment
it, which makes any promise still in flight stale and inert.

Without this, a tooltip hovered twice in quick succession disappears on its own
150ms after the second open: the first close's continuation fires and hides a
layer that is legitimately open again. Tooltip is where this is not an edge case
— it opens and closes on hover, so overlapping cycles are the common path.

`disconnect()` must additionally finish the teardown **synchronously**. Turbo can
detach the element mid-animation, and an awaited continuation would then be
operating on a subtree that is no longer in the document.

## Per-path behaviour

The split is the same everywhere: anything that governs *interaction* happens
immediately, anything that governs *presence in the DOM* waits.

**Immediate.** `data-state="closed"` on content and trigger — first, since it is
what starts the animation — plus `removeLayer` from the dismiss stack (Escape
must not reach a layer that is on its way out), `aria-expanded="false"`, focus
release and restore, scroll unlock, and the `close` event.

**Deferred until settled.** `hidden = true`, moving the content back from the
popper wrapper to its placeholder, `hidePopover()`, and removing the wrapper.

`data-exiting` is written only when there is something to wait for — that is,
only when `whenSettled` returned a promise — and cleared in the same step that
sets `hidden`, including on the synchronous `disconnect()` path. A close with no
animation never puts the attribute in the DOM at all.

### `floating.js#hide`

Scroll and resize listeners are removed immediately, so the layer stops
repositioning while it fades. Radix keeps positioning until unmount; matching
that would need a second flag alongside `this.open`, because `reposition()`
early-returns on it. The visible difference is a layer drifting from its anchor
if the page is scrolled during the exit window. Deliberate: 150ms of drift is
not worth a second piece of open/closed state to keep in sync.

### `dialog_controller`

`render()` goes back to being synchronous and stops writing `hidden` on the way
out; a new `#dismount()` owns the deferred half.

Content and overlay wait on their **own** animations independently — sheet
content is `duration-300` against the overlay's `duration-200`, so a single
shared wait would hold one of them visible past its animation.

### `accordion_controller`

The closing panel keeps `--radix-accordion-content-height` set until the
animation settles. Clearing it early leaves `animate-accordion-up` interpolating
towards a height that no longer exists.

## CSS

Two additions to `app/assets/stylesheets/shadcn.css`.

### The exit window is not interactive

```css
@layer base {
  /* Radix makes closing content non-interactive while it fades. Without this a
     dialog overlay swallows clicks for the 200ms it takes to disappear. The
     marker is written by JS and lives only for the duration of the animation —
     it is not rendered markup. */
  [data-slot][data-exiting] {
    pointer-events: none;
  }
}
```

Keyed on a JS-written `data-exiting` marker rather than on
`[data-state="closed"]`. `data-state="closed"` is also written to **triggers** —
`floating.js` sets it on the trigger, `accordion_controller` on the trigger and
its header — and all of those carry a `data-slot`. Keying on state would make
every closed select, dropdown and accordion permanently unclickable.

### Reduced motion

```css
@utility animate-out {
  /* …unchanged… */
  @media (prefers-reduced-motion: reduce) {
    animation-duration: 0.01ms;
  }
}
```

Same nesting inside `@utility animate-in`.

It has to live *inside* the utility. The components apply these through
variants, so the emitted class is literally named
`data-[state=closed]:animate-out` — a top-level `.animate-out { }` rule matches
nothing.

For the same reason `--animate-accordion-up` and `--animate-accordion-down` move
from `@theme` entries to `@utility` blocks, which is the only place a media
query can reach them. The generated class name is unchanged; only the definition
site moves.

`animate-spin` on Spinner and `caret-blink` are left alone. A frozen loading
indicator communicates worse than the motion it would save.

This is a deliberate departure from upstream: `tw-animate-css` ships no
reduced-motion handling. It is a library-appropriate default, and the departure
is recorded here and in `.claude/docs/decisions/02-javascript.md`.

## Testing

A new `spec/system/exit_animation_spec.rb`.

The failure mode of an animation spec is chasing frames. This one does not: it
reads what the browser **scheduled**, immediately after the close.

```ruby
names = page.evaluate_script(<<~JS)
  document.querySelector('[data-slot="dialog-content"]')
    .getAnimations().map((a) => a.animationName)
JS

expect(names).to include("exit")
```

Either the animation started or it did not — no sleep, no race. Capybara then
waits for the element to go away exactly as it already does.

Coverage: one representative per path (dialog, popover, accordion), plus the two
cases the generation token exists to protect — reopening during the exit window,
and a Turbo navigation mid-exit that must not strand an orphan popper wrapper in
the DOM.

The other suites do not move. Nothing the server renders changes, so `snapshot`
and `parity` are untouched, and no new Stimulus action, target or value is
introduced, so `stimulus_contract` is untouched.

### What this does not prove

That the animation looks right. The spec asserts an animation of the expected
name was scheduled and that the element eventually leaves; it says nothing about
duration, easing, or whether the exit reads as the reverse of the entrance.

## Follow-up

`.claude/docs/decisions/02-javascript.md` currently states that exit animations
never play, and `.claude/docs/todo.md` lists the gap. Both need updating as part
of the change, and the reduced-motion departure recorded.
