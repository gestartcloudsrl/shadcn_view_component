# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Rails engine gem that ports [shadcn/ui](https://ui.shadcn.com) to ViewComponent
**1:1**: same part names, same variants, same Tailwind classes, same `data-slot`
attributes. Radix UI's behaviour is reimplemented in Stimulus — there is no React
and no npm dependency at runtime.

"1:1" is the constraint every decision answers to. When upstream and idiomatic
Rails disagree, upstream wins on *markup* and Rails wins on *API*.

## Commands

```sh
bin/setup                                     # bundle install + build Tailwind
bundle exec rake                              # everything (rspec)
bin/rubocop                                   # Rails omakase style; -a to autocorrect

bundle exec rspec spec/system                 # browser specs only (needs Chrome)
bundle exec rspec spec/system/dialog_spec.rb
bundle exec rspec spec/parity_spec.rb -e "card.tsx"

SNAPSHOTS=overwrite bundle exec rspec spec/snapshot_spec.rb   # regenerate golden HTML

bundle exec rake themes:build                 # regenerate palettes from vendor/shadcn/themes.json

cd test/dummy && bin/rails s                  # gallery at http://localhost:3000/lookbook
cd test/dummy && bin/rails tailwindcss:watch  # keep CSS fresh while editing classes
```

`tailwindcss:build` / `tailwindcss:watch` only work from `test/dummy`, not the
repo root. Without a build the gallery renders **unstyled rather than erroring**,
because the CSS is a compiled bundle.

## Architecture

### The React → Ruby mapping

It all lives in `app/components/shadcn/application_view_component.rb`:

| shadcn | here |
|---|---|
| `cva(...)` | `ViewComponentContrib::StyleVariants` — the `style { base {} variants {} defaults {} }` DSL |
| `cn(...)` | the `tailwind_merge` gem, wired in as the style postprocessor |
| `data-slot="card-header"` | `slot_name :"card-header"` |
| `{...props}` | `**attributes` |
| `asChild` | `as:` |
| Radix primitives | Stimulus controllers under `shadcn--*` |

**Attribute precedence, lowest to highest: `data-slot`, then the component's own
defaults, then the caller's.** What a subclass passes up through `super` in
`#element_attributes` is a *default*, despite arriving as a keyword splat — the
caller's attributes are merged on top, matching React's trailing spread. `class`
and `data-action` are concatenated rather than replaced; `data: { action: … }` is
normalised into `data-action` so both spellings land in one attribute.

Everything is namespaced under `Shadcn::` because `Card`, `Table`, `Field` and
`Select` at top level collide with a host app's models under Zeitwerk.

### Where a component lives

```
app/components/shadcn/
  <family>.rb                  # `part` declarations for the trivial sub-components
  <family>/component.rb        # the family root
  <family>/<part>/component.rb # parts that have behaviour
  <family>/preview.rb + previews/*.html.erb
```

A part that is only an element with a `data-slot` and fixed classes is declared
with the `part` macro (`app/components/shadcn/parts.rb`) on the family module,
not given a file. It gets its own `component.rb` as soon as it has variants,
slots, extra markup, or attributes computed from its arguments.

The family file is `<family>.rb`, a *sibling* of `<family>/`, so Zeitwerk can
resolve `Shadcn::Card::Title::Component` without `Shadcn::Card::Component` having
been loaded first.

### JavaScript

`app/javascript/shadcn/` — 15 controllers plus shared modules: `popper.js`
(hand-rolled positioning, emits the real `--radix-*` custom properties the
Tailwind classes read), `dismiss.js` (layer stack), `focus.js` (trap + scroll
lock), `floating.js` (open/close for popover, tooltip, dropdown, select),
`top_layer.js`, `theme.js`, `id.js`.

Two decisions worth knowing before touching them:

- **Nothing is portalled to `document.body`.** Moving content out of the
  controller's element would unbind the Stimulus actions on close buttons and
  menu items. Instead layers are promoted with the Popover API
  (`top_layer.js`), which escapes stacking contexts without moving anything.
- **Controllers re-sync on `turbo:morph`** (`index.js`). A morph rewrites
  attributes without disconnecting, so `connect()` never runs again; `render()`
  is re-run to put DOM and controller back in agreement.

### Theming

Two independent axes: **mode** (`.dark` on `<html>`) and **theme** (`theme-*` on
`<body>`). Stored in `localStorage`, mirrored to a cookie so
`shadcn_theme_class` / `shadcn_mode` can render server-side.
`shadcn_theme_script_tag` runs before first paint — that is what prevents the
flash.

### Rails forms

`ShadcnViewComponent::FormBuilder` + `shadcn_form_with`. Ids and names from
Rails; error text, `aria-invalid`, `aria-describedby` and `Field`'s
`data-invalid` from `ActiveModel::Errors`.

## Traps

- **Never split a class string across a `\` line continuation.** Tailwind scans
  source text, so half a token generates no CSS. `parity_spec` catches it.
- **Generated files are not to be hand-edited**: `lib/shadcn_view_component/themes.rb`,
  `app/assets/stylesheets/shadcn-themes.css`, and the `shadcn-tokens` block
  inside `shadcn.css`. Edit `vendor/shadcn/themes.json` and run `rake themes:build`.
  CI fails if regenerating produces a diff.
- **Slot content renders before block content.** Mixing the two in one parent
  reorders things — see the select and dropdown previews for why they render
  items in the block.
- **Select, Checkbox and Switch are `<button>`s with an ARIA role.** A
  `<label for>` does not name a button and `role="combobox"` forbids taking the
  name from content, so they need `aria-labelledby`/`aria-label`. The FormBuilder
  does it; a bare component does not.
- **The gallery layout carries its own ModeToggle and ThemeSelector**, so in
  system specs a preview's dropdown or select is not the only one on the page —
  scope lookups (`all("[data-slot=select]").last`).

## What the specs prove

| Spec | Guards against |
|---|---|
| `parity_spec.rb` | a class upstream emits that the port dropped or mistyped — per *family*, not per part, so swapping two variants' bodies stays green |
| `snapshot_spec.rb` | anything that changes rendered HTML: wrong part, wrong variant, attribute drift |
| `stimulus_contract_spec.rb` | a `shadcn--x#action`, target or value a component names but the JS does not define |
| `system/` | behaviour in headless Chrome, including Turbo and stacking contexts |
| `system/accessibility_spec.rb` | axe over every family, at rest and with each layer open |

Parity runs **one way**: when upstream removes a class the port keeps it and
nothing fails. Read the TSX diff when re-syncing.

Previews are both documentation and test fixtures — adding one to a new
component is what gets it covered by the snapshot, preview and accessibility
specs.

## Not ported

chart, sonner, calendar, carousel, resizable, input-otp, command, combobox,
sidebar, menubar, navigation-menu, context-menu, hover-card, scroll-area,
slider, form, item, empty, input-group, button-group, drawer, and the AI chat
components. Several depend on heavy JS libraries and need an explicit decision:
reimplement in Stimulus, or accept an npm dependency.
