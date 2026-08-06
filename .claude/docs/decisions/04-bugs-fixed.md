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
carrying an ARIA role: a `<label for>` does not name a button, and
`role="combobox"` goes further and forbids taking the name from content.
shadcn/Radix have the same gap. The FormBuilder now wires `aria-labelledby`, and
the previews demonstrate it.

## Repositioning forced a synchronous layout per scroll event

`reposition` wrote a transform and immediately read `offsetWidth`, unthrottled,
on `scroll` with capture. Coalesced into one `requestAnimationFrame` — with the
opening placement kept synchronous, or the layer flashes at the top-left for a
frame.

## `bin/setup` raised a `TypeError`

`chdir:` was not a keyword in the `system!` signature, so it reached `system` as
a positional Hash. It survived because nothing ever ran the script — CI did the
steps individually. CI now runs `bin/setup`.
