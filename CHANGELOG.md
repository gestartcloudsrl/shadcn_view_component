# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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
