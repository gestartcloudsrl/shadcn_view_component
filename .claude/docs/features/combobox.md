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

## Multiple selection

`multiple: true` is Base UI's own prop, and as there `value:` then takes an
array. The chips box replaces the field — `combobox_chips` rather than
`combobox_input`, because upstream renders `ComboboxChips` where the
single-selection examples render `ComboboxInput`, with the field moving inside
it as `ComboboxChipsInput`.

**It submits the way Rails reads a collection**: `name` gains `[]` and there is
one hidden input per value, so `params[:project][:languages]` is an array with
nothing to parse. An empty one is rendered first, so removing every chip still
sends the parameter and empties the association rather than leaving it alone —
the same trick `collection_select ... include_hidden: true` plays.

New chips are **cloned from a `<template>`** the Chips component renders, not
built in JavaScript. Building them there would put this library's class strings
in a `.js` file — one Tailwind scans but `parity_spec` does not read, so the
copy would drift from the component in silence and upstream would never be
checked against it.

**The chips field carries its own `aria-label`**, and that is ours in the same
way the trigger's name is. Its only name was the `placeholder`, and the
controller blanks that once there are chips — which upstream's example does
too — leaving a `role="combobox"` with no name and a critical axe `label`
violation. The caller's placeholder is read at render time and kept as the
name, so it stays put while the placeholder comes and goes.

The order of finding it is worth keeping: the placeholder was blanked to fix a
bug visible in a screenshot, the whole suite was green on the run *before* that
change, and the accessibility spec failed on the run after. Neither run was
wrong; the interaction did not exist until the first fix created it.

Two of the rules are **ours**, and marked as such in the system spec's example
names, because Base UI's documentation does not describe either and Base UI is
not vendored here to check against:

- **Taking a chosen option puts it back.** It is what the tick in the list
  invites, and it keeps the list and the chips describing one set.
- **Backspace on an empty field removes the last chip.** The X is a pointer
  target, so without this there is no keyboard way to undo one.

What upstream *does* settle, from its own multiple example, is covered rather
than invented: the panel stays open across choices and the field empties.

## Not reproduced

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
