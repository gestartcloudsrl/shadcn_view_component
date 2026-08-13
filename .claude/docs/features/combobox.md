# Combobox

*Adapted: 1:1 in markup, and the only family in this gem answerable to **Base
UI** rather than Radix.*

`combobox.tsx` is 310 lines over `@base-ui/react` — and it is the one file of
the 61 in `vendor/shadcn/ui/` that imports it. That is not a detail: it decides
what "1:1" means here.

## Base UI's names, in this family and nowhere else

The class strings say it plainly:

| upstream writes | the rest of this gem writes |
|---|---|
| `data-open:` / `data-closed:` | `data-[state=open]:` |
| `--anchor-width`, `--available-width`, `--available-height`, `--transform-origin` | `--radix-popper-*` |
| `data-highlighted` | `data-highlighted` — the one they agree on |

So this family emits `data-open` / `data-closed`, and `popper.js` publishes the
four unprefixed custom properties **when asked** — `publishBaseUiVariables`,
which only this controller passes. Publishing them everywhere would put
`--anchor-width` into every floating layer in a host's page, and that is a name
a host may already be using.

## Three things the rendered example settled

Reading the source would have got each of them wrong, and the port had two of
them wrong until the page was opened:

- **There is no `combobox-input`.** Upstream renders
  `<ComboboxPrimitive.Input render={<InputGroupInput/>}/>`, so the field carries
  `data-slot="input-group-control"`. The slot this port first invented does not
  exist anywhere upstream.
- **The trigger's slot is `input-group-button`.** `ComboboxTrigger` sets
  `combobox-trigger`, and the wrapper that renders it with `asChild` sets its
  own last — so the button ends up with the wrapper's name. `parity_spec` holds
  `combobox-trigger` in `allowed_missing` with that reason.
- **The field is `role="combobox"` with `aria-haspopup="listbox"`**, and the
  trigger is a second `role="combobox"` with `aria-haspopup="dialog"`.

## What is ours

- **The trigger has a name.** Upstream's is a `role="combobox"` containing a
  chevron and no text, which axe fails as `button-name` — the same correction
  Select, Checkbox and Switch needed here.
- **`isolate z-50` rides on the panel.** They are upstream's *Positioner*
  classes, and this port has no element for it: `floating.js` makes the wrapper.
- **A hidden input**, so the chosen value submits with the form the way every
  other control in this gem does.
- **`shadcn--combobox:select`** and **`shadcn--combobox:remove`**, where
  upstream takes callbacks.

## What the panel opens on

`click`, not `focus`. Taking an option puts the caret back in the field, and on
`focus` that reopened the panel the choice had just closed — found by a spec. A
pointer opens it by clicking and a keyboard by pressing Down, which is what both
do anyway.

## Not reproduced

- **Adding chips.** The chips markup is ported — the box, the token, the X, the
  field that sits among them — and *removing* one works. What is not wired is
  the other half: choosing an option while in chips mode should add a token and
  extend a multi-valued parameter, and it does not yet. Single selection is
  complete.
- **`ComboboxCollection`**, Base UI's render-prop helper: it takes an array and
  renders an item per entry. In ERB that is a loop, and a loop has no element to
  put a slot on. Also in `allowed_missing`.
- **`ComboboxValue`** is ported as a `part`, but nothing here writes into it:
  the field itself shows the chosen label, which is what the single-select
  examples do.
- **Base UI's own filtering knobs** (`filter`, `itemToStringValue`,
  `grid`, virtualisation) and its `openOnInputClick` / `modal` props.

## The filter is a contains match

Base UI's default, and the same call the searchable select makes — a combobox
completes a value from a list its caller ordered. The palette ranks instead,
because it answers a different question; both decisions are written up in
[features/command.md](command.md).
