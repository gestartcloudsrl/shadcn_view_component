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

## Components not ported (23)

All 27 unported sources were vendored, so this list is derived from what they
actually import rather than from memory, and `spec/parity_spec.rb` holds it as
`not_yet_ported` and fails if the two drift. Four have since been ported —
`empty`, `button-group`, `input-group`, `item` — leaving 23.

The grouping this replaced was wrong in four ways, each recorded below. A fifth
error was mine, and is recorded with the group it belongs to.

- **Markup only** (4 left): `message`, `bubble`, `attachment`, `marker` — no
  library, `radix-ui` only for `Slot`, no state and no event handlers.
  *All four were filed under "AI chat set", which implied a difficulty they do
  not have — `message` imports nothing whatsoever. They are now the easiest
  things left in the backlog.*

  *`input-group` was in this group and should not have been.* It has an
  `onClick` on its addon — clicking the addon focuses the group's control — so
  it needed a Stimulus controller and a system spec. The classification missed
  it because it was reached by grepping for React hooks and not for inline
  event handlers. All eight candidates were re-checked with the right
  instrument afterwards; `input-group` was the only one affected.

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

- [ ] **`select_controller` and `dropdown_menu_controller` share ~60 near-identical
      lines** (roving focus, typeahead) with *deliberate* divergences that nothing
      marks as intentional — dropdown wraps around, select clamps.
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
- [ ] **Closing content stays focusable while it fades.** `hidden` is what takes
      it out of the tab order, and that now waits for the animation.
      `[data-slot][data-exiting]` stops clicks everywhere except the accordion,
      which the rule excludes; either way it never touches Tab or a screen
      reader. Radix also removes it from the tab order; `inert` would.
- [ ] **Two previews claim `<label for>` cannot name a `<button>`.**
      `switch/previews/default.html.erb` and `field/previews/default.html.erb`
      both say so, and it is exactly the misconception
      [04-bugs-fixed.md](decisions/04-bugs-fixed.md) exists to correct — a
      button is a labelable element. `checkbox`'s own preview relies on the
      opposite and passes axe. Previews are documentation, so this is a
      falsehood the gem ships.
- [ ] **`icon.rb`'s two comments disagree with each other.** The header now says
      no autoloadable constant resolves in an initializer; fifteen lines below,
      the comment on the delegating `.register` still describes it as what a
      host calls "once, at boot" — the one context it does not serve.
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
