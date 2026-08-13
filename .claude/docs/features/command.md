# Command

*Adapted: 1:1 in markup, rebuilt on a ported scorer instead of `cmdk`.*

`command.tsx` is 184 lines over `cmdk` — 1,091 lines of TSX plus a 162-line
fuzzy scorer, over four Radix packages, vendored at `vendor/cmdk/`. Every class
is in the TSX, and unlike `chart.tsx` its selectors reach a DOM this port
renders, which decided the shape of the port.

## The `cmdk-*` attributes are part of the contract

shadcn spaces the palette out with `[&_[cmdk-group-heading]]:px-2`,
`[&_[cmdk-item]]:py-3`, `[&_[cmdk-input-wrapper]_svg]:h-5` and a dozen more —
selectors into the library's own attributes. So the parts carry them:
`cmdk-root`, `cmdk-input`, `cmdk-input-wrapper`, `cmdk-list`, `cmdk-empty`,
`cmdk-group`, `cmdk-group-heading`, `cmdk-group-items`, `cmdk-item`,
`cmdk-separator`.

That is the difference from the chart, where the equivalent classes select a
DOM this port does not render and are listed in `allowed_missing` instead. Here
rendering them makes upstream's own rules apply — most visibly in the dialog,
where the whole palette's spacing comes from them.

## The scorer is ported, not replaced

`app/javascript/shadcn/command_score.js` is `vendor/cmdk/command-score.ts` in
JavaScript, weights and comments intact. It is here rather than a substring test
because **the ranking is the component**: type `gp` and cmdk puts *Group Policy*
above *Groups*, because a match at the start of a word scores 0.89 against 0.17
for one in the middle. A palette answers "what did you mean"; a list that
filters by `includes` does not.

This is the opposite call from the searchable select, and deliberately: that one
filters a list its caller ordered and keeps that order. Here items are sorted
within their group, and the groups by their best item — an answer under a
heading nobody is looking at is not an answer.

`keywords:` are searched and never shown, which is how *Preferences* is found by
typing `settings`.

## What is ours

- **`shadcn--command:select`**, carrying the chosen value. Upstream takes
  `onSelect` per item, and a callback has no markup.
- **The virtual focus** — `aria-activedescendant` from the input, the caret
  never leaving it — is cmdk's arrangement and this gem's own, shared with the
  searchable select.
- **The order to go back to.** An empty query restores what the server
  rendered, which the controller remembers on connect.

## Two places upstream's markup was corrected

- **The separator is `aria-hidden`, not `role="separator"`.** A `role="listbox"`
  may only contain options and groups, and upstream's own example puts the
  separator inside the list — so cmdk's markup makes the listbox invalid and axe
  fails it. Nothing is lost: a separator with no name conveys nothing, and the
  groups either side are already named. Same call the toaster made about a
  `role` on an `<li>`.
- **The empty state is not hidden with the list.** It lives *inside* the list,
  so hiding the list when nothing matches hides the message saying nothing
  matches. The searchable select hides its list because its empty state is a
  sibling; this one is not. Found by a spec, in the first version.

## Not reproduced

- **`shouldFilter={false}`** and a caller-supplied `filter` function. The
  scorer is the filter here; server-side filtering is a Turbo Frame away and
  needs no prop.
- **`loop={false}`** — the walk wraps, which is cmdk's default and what a ring
  of six items wants.
- **`vim` bindings** (`ctrl+n`/`ctrl+p`/`ctrl+j`/`ctrl+k`) and the
  group-jumping `alt+arrow`.
- **`CommandLoading`**, and the `--cmdk-list-height` custom property cmdk
  publishes for animating the list's height.
- **`value` / `onValueChange` on the root** — the selection is the DOM's
  `data-selected`, and the event above is what a caller listens to.

## The dialog

`Command::Dialog` is a Command inside this gem's Dialog, as upstream's is.
Its title and description are `sr-only` and defaulted rather than optional,
because a dialog with no accessible name opens into silence.

Its trigger slot keeps the caller's block and hands it to the Dialog's own
trigger with `view_context.capture` — capturing inside this component writes to
the wrong buffer and the button comes out empty, which axe reported twice before
the shape was right.
