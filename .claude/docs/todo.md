# TODO

Ordered by what blocks a release, then by value. Rationale for anything already
decided is in `decisions/`.

## Before publishing

- [ ] **Create the GitHub repository and push.** The gemspec already points at
      `github.com/sirion1987/shadcn_view_component`; the URLs are dead until it
      exists. `git remote add origin … && git push -u origin main`.
- [ ] **Decide the version.** Still `0.1.0`. The API is stable enough to mean it,
      but `part`, the FormBuilder and the `Shadcn::` namespace are all recent.
- [ ] **Check the CI actually passes on GitHub.** It has only ever run locally.
      The browser specs need `browser-actions/setup-chrome`, which is configured
      but unproven.

## Coverage gaps worth closing

- [ ] **Reverse parity.** When upstream *removes* a class the port keeps it and
      nothing fails. A naive check was measured and rejected (see `decisions/`);
      the workable version keys on `data-slot` rather than on the directory.
- [ ] **A screen-reader pass.** axe covers names, roles, required parents and
      contrast. It does not tell you whether the experience makes sense in
      VoiceOver or NVDA — for a library whose pitch is Radix's accessibility,
      that is the claim least tested.
- [ ] **Exit animations do not play.** `hidden` is set immediately on close, so
      every `data-[state=closed]:animate-out` class is inert. The markup matches
      shadcn; the behaviour does not. Planned in
      [plans/2026-08-06-exit-animations.md](plans/2026-08-06-exit-animations.md),
      which waits on `getAnimations()` rather than `animationend`, and finds a
      third closing path this entry used to miss — the accordion.
- [ ] **`transform`/`filter`/`contain` ancestors.** The top layer solved *what
      paints over* a floating layer; an ancestor that becomes the containing
      block still affects *where it is positioned*. Not reproduced yet.

## Components not ported (27)

Needs a decision before any work: reimplement in Stimulus, or accept an npm
dependency for the four that are effectively a library each.

- **Heavy JS**: chart (recharts), calendar (react-day-picker), carousel (embla),
  command/combobox (cmdk), sonner (toast), input-otp, resizable
- **Plain ports, no blocker**: sidebar, menubar, navigation-menu, context-menu,
  hover-card, scroll-area, slider, item, empty, input-group, button-group,
  drawer, form
- **AI chat set**: message, message-scroller, bubble, attachment, marker,
  direction

Most wanted in a real Rails app, roughly: command, calendar, sonner, sidebar,
combobox, slider.

## Smaller things

- [ ] **`Icon::Component` raises on an unknown name**, which turns a typo into a
      production 500, and bundles only the 11 lucide icons the ported components
      use. No escape hatch for the other ~1,500.
- [ ] **ARIA is set twice** — in Ruby at render and again in the controller on
      connect (`select/trigger` vs `select_controller`, same for popover, dialog,
      dropdown). Two places to drift.
- [ ] **`select_controller` and `dropdown_menu_controller` share ~60 near-identical
      lines** (roving focus, typeahead) with *deliberate* divergences that nothing
      marks as intentional — dropdown wraps around, select clamps.
- [ ] **`previews_spec` and `snapshot_spec` overlap.** Both render every preview;
      the former only asserts it does not raise.
- [ ] **Two components name their trigger differently.** `ThemeSelector` uses
      `<label for>` pointing at the trigger; the FormBuilder uses
      `aria-labelledby`. Both pass axe — `<button>` is a labelable element — but
      one of them should probably follow the other.
- [x] **`bin/console`** — boots the dummy so components can be rendered by hand.

## Deliberately not doing

- **Reverse parity as a token-set diff** — measured, 12 of 13 families dirty with
  false positives.
- **Portalling to `document.body`** — unbinds the Stimulus actions inside the
  content. The Popover API solved the problem it was meant to solve.
- **A `<dialog>.showModal()` rewrite** — the Popover API already fixed the
  stacking-context issue with far less change.
