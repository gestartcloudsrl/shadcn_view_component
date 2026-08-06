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
hesitate — and they never play today anyway, because closing sets `hidden`
immediately, so every `data-[state=closed]:animate-out` class is inert. Worth
knowing before anyone tries to add them; see [todo](../todo.md).

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
