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
- [ ] **`transform`/`filter`/`contain` ancestors.** The top layer solved *what
      paints over* a floating layer; an ancestor that becomes the containing
      block still affects *where it is positioned*. Not reproduced yet.

## Components not ported (27)

All 27 are now vendored, so this list is derived from what the sources actually
import rather than from memory. `spec/parity_spec.rb` holds the same list as
`not_yet_ported` and fails if the two drift.

The grouping this replaced was wrong in four ways, each recorded below.

- **Markup only** (8) — no library, `radix-ui` only for `Slot`, no React state
  at all: `empty`, `input-group`, `button-group`, `item`, `message`, `bubble`,
  `attachment`, `marker`.
  *Four of these were filed under "AI chat set", which implied a difficulty they
  do not have — `message` imports nothing whatsoever.*

- **Radix behaviour to reimplement in Stimulus** (7): `hover-card` (44 lines),
  `scroll-area` (58), `slider` (63), `navigation-menu` (168), `context-menu`
  (252), `menubar` (276), `direction` (22).
  *Six of these were filed as "plain ports, no blocker". They are the same class
  of work as `dropdown_menu` and `select` — roving focus, typeahead, submenus,
  drag — not the same class as `badge`.*

- **Blocked by a third-party npm package** (10): `drawer` (vaul), `chart`
  (recharts), `command` (cmdk), `carousel` (embla-carousel-react), `input-otp`,
  `sonner` (+ next-themes), `resizable` (react-resizable-panels), `calendar`
  (react-day-picker), `combobox` (**@base-ui/react**), `message-scroller`
  (**@shadcn/react/message-scroller**).
  *Two of these were not recorded as blocked at all. `combobox` has moved off
  Radix to Base UI, so reimplementing it means tracking a second headless API
  rather than the one already understood; `message-scroller` depends on a
  package shadcn publishes itself. `drawer` was filed as a plain port and is
  vaul.*

- **Cases of their own** (2): `form` is react-hook-form, and the Rails answer is
  the FormBuilder that already exists plus `field`, already ported — so it may
  be a question already answered rather than a port. `sidebar` is 726 lines
  composing sheet, tooltip, button, input, separator and skeleton, with a
  `use-mobile` hook; it was filed as a plain port and is the largest component
  in shadcn.

The old list said "command/combobox" on one line. They are two files upstream,
which is why the total was 27 and not 26.

Most wanted in a real Rails app, roughly: command, calendar, sonner, sidebar,
combobox, slider — which is, awkwardly, five of the twelve hardest.

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
- [ ] **A layer stops following its anchor while it fades.** `floating.js#hide`
      drops the scroll and resize listeners immediately, so a layer scrolled
      during its exit animation detaches from the trigger for the length of it.
      Radix is understood to keep positioning until unmount — not checkable
      here, since only shadcn's TSX is vendored, not Radix. Matching that needs
      a second flag beside `this.open`, which both `reposition()` and
      `applyPosition()` return early on.
- [ ] **`--animate-caret-blink` was left out of the reduced-motion pass.** It is
      the only `infinite` animation in `shadcn.css` and so the strongest
      candidate of the lot, and it got neither of the two things the others
      did: it is still in the `@theme inline` block rather than the plain
      `@theme` a host can retune at runtime, and no `@media
      (prefers-reduced-motion: reduce)` collapses it. `reduced_motion_spec`
      cannot see the gap either — its scan looks for `animate-in`/`animate-out`/
      `animate-accordion-*` in `app/components`, and nothing there uses this
      one. Nothing consumes it today: InputOTP, the component it exists for, is
      unported.
- [ ] **The gem's `!important` rules cannot be overridden the ordinary way.**
      `[data-slot][hidden]`, `[data-slot][data-exiting]` and the two
      `animate-accordion-*` overrides all carry `!important` from inside a
      cascade layer, and a layered `!important` beats an unlayered one at any
      specificity — so a host cannot switch one off with an `!important` of
      their own either, only inline or from a layer declared earlier. Each rule
      says in place why it is `!important`; nothing says anywhere that this is
      the constraint the set of them adds up to. `02-javascript.md` records it
      only from the side that bit the test harness.
- [ ] **`exit_animation_spec.rb` overlaps itself.** The AlertDialog
      `elementFromPoint` example is largely subsumed by the click example
      beneath it — a click that reaches the content proves the content is on
      top — and a `have_no_css(overlay)` line is repeated across two examples in
      the dialog group.
- [ ] **Closing content stays focusable while it fades.** `hidden` is what takes
      it out of the tab order, and that now waits for the animation.
      `[data-slot][data-exiting]` stops clicks everywhere except the accordion,
      which the rule excludes; either way it never touches Tab or a screen
      reader. Radix also removes it from the tab order; `inert` would.
- [ ] **A local run can assert against a stale Tailwind bundle.**
      `reduced_motion_spec` builds it, but in a `before` hook — so only before
      its own examples, and `config.order = :random`. On a seed that puts it
      after `exit_animation_spec`, an example there can pass against whatever
      the last build left on disk. CI is safe because `bin/setup` builds first.
      The hook is still the right place: the build used to run while specs were
      *loading*, where a broken build killed all 546 examples before any of
      them could say why. What is missing is a decision about where a suite-wide
      build belongs, not a revert.
- [x] **`bin/console`** — boots the dummy so components can be rendered by hand.
- [x] **Exit animations** — every `data-[state=closed]:animate-out` class was
      inert, on three closing paths rather than the two this list used to name.
      See [decisions/02-javascript.md](decisions/02-javascript.md).

## Deliberately not doing

- **Reverse parity as a token-set diff** — measured, 12 of 13 families dirty with
  false positives.
- **Portalling to `document.body`** — unbinds the Stimulus actions inside the
  content. The Popover API solved the problem it was meant to solve.
- **A `<dialog>.showModal()` rewrite** — the Popover API already fixed the
  stacking-context issue with far less change.
