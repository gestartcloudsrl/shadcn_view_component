# Resizable

*Adapted: 1:1 in markup, rebuilt on flex shares instead of
`react-resizable-panels`.*

`resizable.tsx` is 53 lines — three wrappers with all the classes in them, over
a package of 2,252 lines and no dependencies of its own. Applying the rule in
[01-architecture.md](../decisions/01-architecture.md#when-a-package-can-be-dropped-and-when-it-cannot):
what the package supplies is a drag, a keyboard and arithmetic over `flex-grow`.
The layout is the browser's — panels are shares of a flex container — so the
controller only has to move two numbers and let it lay the group out again.

## What is 1:1

Every class, from all three parts, and the DOM the package renders:

- **The group** — `data-slot="resizable-panel-group"`, a flex container.
- **The panel** — `data-slot="resizable-panel"`, sized by `flex-grow` against
  `flex-basis: 0`, which is exactly the proportional layout the package
  computes.
- **The handle** — `data-slot="resizable-handle"`, `role="separator"`,
  `tabindex="0"`, `data-separator="inactive"|"active"`, and the grip behind
  `with_handle:`.
- **The keyboard**, read from the package's own switch: five points an arrow
  press, Home and End all the way, and the arrows *across* the group's axis do
  nothing.

## The one thing worth knowing about the group

Upstream's class list contains `aria-[orientation=vertical]:flex-col`, so the
obvious port writes `aria-orientation` on the group. axe refuses it: no role a
plain group can carry supports that attribute.

Reading what `react-resizable-panels` v4 actually renders settles it — the group
has **no role and no `aria-orientation` at all**, and sets `flex-direction`
inline. So the class is vestigial upstream too: it reads an attribute the
package stopped rendering. This port does the same thing, and keeps the class,
because `parity_spec` compares what upstream *emits* and dropping it would claim
a divergence that is not one.

The handle is the opposite case: `role="separator"` does support
`aria-orientation`, so its own classes work, and its orientation is always
written because a separator defaults to horizontal.

## What is ours

- **`aria-valuenow`, `aria-valuemin`, `aria-valuemax` and `aria-controls`** are
  written by the controller rather than rendered. The server would have to know
  how many panels a caller put in the block, and with panels and handles written
  in the block — which is what a group *is*, `panel, handle, panel` — it does
  not.
- **`shadcn--resizable:resize`**, carrying the sizes. Upstream takes an
  `onLayout` callback, and a callback has no markup.

## Not reproduced

- **`autoSaveId`**, the package's localStorage persistence. A Rails app has a
  better place to keep a layout than the browser does, and the event above is
  what it would be saved from.
- **Collapsible panels** — `collapsible`, `collapsedSize`, and the `Enter` that
  toggles them.
- **Conditional panels**, `order`, and the imperative handle (`resize`,
  `collapse`, `expand` from a ref).
- **Group-level `keyboardResizeBy` and `dragInterval`**; the step is the
  package's own 5.
- **`onDragging`, `onCollapse`, `onExpand`** — one event covers what the port
  does.

## Where the sizes live

`default_size:`, `min_size:` and `max_size:` are percentages, as upstream's are.
**Give every panel a size or give none**: with a mix, a panel without one takes
a single share against another's twenty-five, which is not what anybody means.
Without any, `flex-grow: 1` each divides the group equally, and the controller
reads the shares back from the layout rather than from the style — so a group
that was never given sizes still has numbers to move.
