# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- An option added to a `Select`, `Combobox` or `Command` after its controller
  connected now gets an id, so `aria-activedescendant` has something to point
  at. The ids were handed out once in `connect`, which only ever saw what the
  server rendered — anything appended later arrived without one, the attribute
  pointed at nothing, and the highlight moved on screen while a screen reader
  followed none of it. Silent, and invisible to anyone not listening.

  The id is assigned where it is read instead, so it no longer matters when or
  by whom the option was created. Found wiring a dependent select in a host app:
  choosing a client refills the sites beside it.

## [0.3.0] — 2026-08-18

### Added

- **`input_attributes:` on `Select`, `RadioGroup` and `ToggleGroup`**, reaching
  the hidden input that carries the control's value into the form and nothing
  else. That input is the library's own invention — Radix bubbles a native
  control instead — and a host had no way to name it. `id`, which a
  `<label for>` or an external script needs, and `form`, which is how HTML lets
  a control submit with a form it does not sit inside, had no workaround at all.
  `name` and `value` stay the component's.

  Not offered on Combobox in `multiple` mode, Slider with several thumbs or
  Calendar in `range`/`multiple`: those render several inputs, and copying a
  caller's attributes onto each would duplicate `id` and connect a
  `data-controller` once per input. Those take their attributes on the root.

  Every rendered snapshot is unchanged: the attribute order the components
  emitted before is preserved.

## [0.2.1] — 2026-08-17

### Fixed

- `data-controller` from a caller now concatenates onto the component's own
  instead of being emitted twice. `data-action` was given this treatment
  already; `data-controller` was missed, and its failure is quieter — two
  attributes is invalid HTML, the browser keeps the first, which is the
  component's, so the *caller's* controller never connects with nothing logged
  and the component still working. Found in a host app wiring a dependent
  select: `data: { controller: "set-location" }` on a Select, and choosing a
  client silently stopped reloading its locations.

## [0.2.0] — 2026-08-17

### Added

- **Multiple selection in `Combobox`.** `multiple: true` takes an array in
  `value:` and renders the chips box in place of the field, through a new
  `combobox_chips` slot. Choosing an option adds a chip, taking it again puts it
  back, and Backspace on an empty field removes the last one. It submits as a
  Rails collection — `name` gains `[]`, one hidden input per value, plus an
  empty one so clearing every chip still sends the parameter. The chips markup
  was already ported; adding one is what was missing. Two of the rules are ours
  rather than upstream's, because Base UI documents neither and is not vendored
  here to check against; both are named as such in the system spec. See
  [features/combobox.md](.claude/docs/features/combobox.md).

- `bin/eslint`, and a lint step for it in CI. It covers the one thing Ruby
  tooling cannot see: whether the JavaScript refers to something that exists.
  `stimulus_contract_spec` checks the other direction, from the components in.
  Node is a development dependency and only that — the gem ships no npm package
  and needs none at runtime.

### Fixed

- `shadcn_t` did not fall back to the bundled English, though the comment above
  it had claimed it did since it was written. Every string the components render
  went through a bare `I18n.t`, so a host whose locale was not `en` got
  `I18n::MissingTranslationData` — and with `config.i18n.raise_on_missing_translations`,
  which the Rails generators turn on in development and test, a raised page
  rather than a fallback string. Found by installing the gem in an Italian app,
  where the searchable select took the page down.

- `MessageScroller`'s controller called `getContentBottom`, which is exported by
  `scroll_geometry.js` and was never imported there. The method around it was
  called by nothing, so it is gone rather than repaired — it would have thrown
  for the first caller. Found by eslint's first run.

## [0.1.0] — 2026-08-17

The first release. shadcn/ui ported to Rails ViewComponent 1:1 — the same part
names, variants, Tailwind classes and `data-slot` attributes — with Radix UI's
behaviour reimplemented in Stimulus, and no React and no npm at runtime.

### Added

- **Every component in the vendored registry.** 64 families under `Shadcn::`,
  from `Accordion` to `Tooltip`, with `parity_spec`'s `not_yet_ported` list
  empty. `form` is the one deliberate exception: it is answered by a Rails
  FormBuilder rather than transcribed, since Rails already owns ids, names and
  errors.
- **32 Stimulus controllers**, one per family with behaviour, over shared
  modules for positioning (`popper.js`, `floating.js`), the dismiss stack, the
  focus trap, the browser's top layer, typeahead and exit animations.
- **Shapes drawn on the server where the React version reaches for a package.**
  The calendar builds its own months, the carousel its own track, the OTP input
  its own boxes, and the chart draws pie, bar, line and area over a `Chart::Plot`
  that computes the scale, the ticks and the bands — because `chart.tsx` draws
  nothing at all, and recharts is 29,091 lines. Where a package *is* the work,
  that is recorded rather than pretended away.
- **The icons are lucide's own files**, vendored under `vendor/lucide/icons` and
  generated into the registry the component reads. A host adds its own with
  `IconRegistry.load_directory`, a directory of SVGs and one line — no asset
  pipeline involved.
- **An accessibility audit in both palettes**, over every preview, at rest and
  with each layer open. The colour scheme is pinned, because headless Chrome
  otherwise takes it from the desktop it runs on and audits whichever palette
  the author is sitting in front of.

- RuboCop, on [Rails omakase](https://github.com/rails/rubocop-rails-omakase) —
  which is the style the codebase was already written in — with `bin/rubocop`
  and a lint job in CI. The generated theme registry, the dummy application and
  the vendored shadcn sources are excluded.
- An axe audit over every family, at rest and with each layer open, plus
  contrast in dark mode. It found that Select, Checkbox and Switch reached the
  browser with no accessible name — a `<label for>` does not name a `<button>`,
  and `role="combobox"` forbids taking the name from content. The FormBuilder
  now wires `aria-labelledby` for them, and the previews demonstrate it.
- System specs driving headless Chrome against the gallery, so the
  Stimulus controllers, `popper.js`, the dismiss stack and the focus trap are
  executed rather than merely name-checked. They cover open/close, keyboard
  navigation, focus trapping and restoration, scroll locking, positioning and
  flipping, ARIA wiring, and mode/palette persistence across reloads.
- `shadcn_form_with` and `ShadcnViewComponent::FormBuilder`, wiring the `Field`
  family to a model: ids and names from Rails, error text, `aria-invalid`,
  `aria-describedby` and `data-invalid` from `ActiveModel::Errors`. Controls for
  input, textarea, native select, select, checkbox, switch, radio group and
  submit.
- A `part` macro for the sub-components that are only an element with a
  `data-slot` and fixed classes. Declared on the family module, they no longer
  need a file each — 53 files and their directories are gone, and a family now
  reads on one screen. The generated classes are identical, which the rendered
  snapshots confirm.
- Theming: 24 shadcn palettes generated from the upstream registry, a
  `shadcn--theme` Stimulus controller, `ModeToggle`, `ModeSwitcher` and
  `ThemeSelector` components, and `shadcn_theme_script_tag` to apply the stored
  preference before the first paint.
- `bin/rails generate shadcn_view_component:install`, which resolves the
  Tailwind `@source` path from the loaded gem instead of asking you to guess
  where bundler put it.
- Every user-visible string goes through I18n under `shadcn_view_component.*`,
  with shadcn's English as the default.
- `spec/snapshot_spec.rb`: golden snapshots of the rendered HTML for every
  preview, which is what catches a class that moved to the wrong part or the
  wrong variant.
- `spec/stimulus_contract_spec.rb`: asserts every `shadcn--x#action`, target and
  value a component emits exists on the matching controller.
- `config.shadcn_view_component.cache_size` for tailwind-merge's LRU, defaulting
  to 10,000 rather than the gem's 500.

### Fixed

- The controllers re-sync on `turbo:morph`. A morph refresh rewrites attributes
  in place without disconnecting them, so `connect()` never ran again and the
  DOM went back to the server's state while the controller kept the old ids,
  targets and open/closed state. The dummy app now runs Turbo, and
  `spec/system/turbo_spec.rb` covers Drive navigation, cache restoration and
  morph refreshes.
- Floating layers and modals are promoted to the browser's top layer with the
  Popover API, so a stacking context above them — a `sticky z-40` header, an
  `isolate` card, anything with `opacity < 1` — can no longer bury them. They
  stay where they are in the DOM, so the Stimulus actions inside them keep
  working. Browsers without the API keep the previous `position: fixed`
  behaviour.
- Attributes passed by the caller now win over the component's own, matching
  React's `{...props}` spread. Previously `Icon.new("x", width: "16")` rendered
  `width="24"` and every caller override was silently ignored.
- `data: { action: … }` no longer emits a second `data-action` attribute. The
  duplicate was invalid HTML, and the browser kept the first — so the
  component's own action never fired.
- DOM ids use a counter instead of `crypto.randomUUID()`, which is defined only
  in a secure context: over plain HTTP the controllers threw on connect and
  dialog, select, dropdown and tooltip were silently dead.
- Escape no longer stops propagating at the document capture phase, where an
  open layer — a tooltip was enough — swallowed the key for the whole page.
- Floating content returns to its original position in the DOM instead of the
  end of its container, which reordered the markup after one open/close.
- Repositioning is coalesced into one animation frame, instead of forcing a
  synchronous layout on every scroll event.
- The gem ships its own `[data-slot][hidden]` rule rather than relying on
  Tailwind's preflight, which a host app may not import — without it every
  dialog, sheet, dropdown and select painted open on load.
- `:root` and `.dark` are generated from the same registry data as the palettes,
  so the default look really is `theme-neutral`. They had drifted.

### Removed

- The `surface-*`, `code-*`, `selection-*` and `destructive-foreground` tokens.
  They dress ui.shadcn.com's own chrome, no ported component uses them, and no
  registry palette defines them.
- Dead scaffolding from `rails plugin new`: `test/test_helper.rb` (no minitest
  tests exist), and the dummy's `config/ci.rb`, `bin/ci` and `bin/setup`, which
  ran `bin/rails test` against nothing.
