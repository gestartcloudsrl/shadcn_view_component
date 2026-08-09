# Navigation menu

**Verdict: adapted — one of upstream's two configurations, and the other cannot
be reproduced here.**

**Status: complete, in `viewport={false}`.**

**Upstream:** `vendor/shadcn/ui/navigation-menu.tsx` — 168 lines over Radix's
`NavigationMenu`, 1,403, vendored at `vendor/radix/ui/navigation-menu.tsx`.

---

## The decision this port turns on

Upstream's default renders every panel into **one shared box** — the viewport —
which animates between their sizes as you move along the row. Measured on the
live demo: an open panel's parent is `navigation-menu-viewport`, which means
React has moved it there through a portal.

Nothing is portalled in this gem
([decisions/02-javascript.md](../decisions/02-javascript.md)), because moving
content out of a controller's element unbinds the Stimulus actions inside it.
So that mode is not available here without giving up the rule every other
component was built on.

**`viewport={false}` is what ships**, and it is not a workaround: it is a
configuration shadcn supports and ships classes for. Each panel stays inside its
own item and takes its own border, background, shadow and zoom — every class in
`navigation-menu-content` that reads
`group-data-[viewport=false]/navigation-menu:` is doing that work.

The root renders `data-viewport="false"` and no viewport element. Shipping an
empty one would put something in the page that looks like the component working;
its classes are declared in `parity_spec`'s `allowed_missing` with this reason.

## What that costs

- **No cross-panel size animation.** Panels appear and disappear under their own
  triggers rather than one box growing between shapes.
- **`data-motion` still applies.** The controller compares the item you left
  with the one you reached, so panels slide from the side you came from — that
  half survives.

## Also not reproduced

- **`NavigationMenuSub`.** Radix has one; shadcn does not export it, so it is
  not part of this port's surface.
- **Vertical orientation.** Radix takes `orientation`; shadcn's example is a
  row, and the arrow handling here is horizontal.

## The delays are the component

`delay_duration` 200ms and `skip_delay_duration` 300ms, both Radix's own
(`navigation-menu.tsx:136-137`). The first stops a pointer sweeping past from
flashing panels open. The second is the grace period after a panel closes, in
which the next one opens with no wait at all — without it a menu feels stuck
once you are already inside it.

## Where each claim is enforced

| Claim | Enforced by |
|---|---|
| the shipped delays, and `data-viewport="false"` with no viewport element | `spec/system/navigation_menu_spec.rb` |
| a pointer that crosses and leaves opens nothing | same file, mutation-verified |
| the grace period after a close | same file, mutation-verified |
| one panel at a time, and which side it arrives from | same file, mutation-verified |
| Escape closing and returning focus, ArrowDown stepping into the panel | same file, mutation-verified |
| the indicator sitting under the open trigger | same file, mutation-verified |

**Two of those examples asserted nothing until a mutation said so**, and both
for the same reason: `have_css` retries for two seconds, so an assertion made
after a 400ms delay is satisfied whether the delay was honoured or not. Anything
about *timing* here reads the state at a chosen moment instead — and the read
has to come **before** the competing timer, since leaving also schedules a
close and a panel that opened instantly is shut again by the time a later read
arrives.
