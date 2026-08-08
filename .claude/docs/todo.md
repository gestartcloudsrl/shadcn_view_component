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

## Upstream has three variants now, and Radix is not the one it shows first

Observed on 2026-08-08 by opening the docs:
`ui.shadcn.com/docs/components/dropdown-menu` **redirects to
`/docs/components/base/dropdown-menu`**, and the page offers three tabs — Base
UI, React Aria, Radix UI — in that order. This gem ports the Radix variant (37
of the 61 files in `vendor/shadcn/ui/` import `radix-ui`).

They are not the same component. Driven from the keyboard, ArrowDown on the last
item wraps to the first in the Base UI demo and does not move in the Radix one —
the divergence that started this entry. That is a default, not a behaviour:
Base UI's `Menu.Root` takes `loopFocus`, `boolean`, **defaulting to `true`**,
where Radix's `loop` defaults to `false`. Same knob, opposite ends. Read from
base-ui.com's API reference, not from Base UI's source.

Base UI documents no prop for typeahead, its buffer or its timeout, on either
Menu or Select — but its release notes list "Reset typeahead on external blur"
as behaviour, which Radix also does (vendor/radix/ui/menu.tsx:585-590) and this
port still does not. That is the open "typeahead buffer survives a close" entry
below, now wanted by two upstreams rather than one.

What is *not* established: whether shadcn considers the Radix variant legacy,
deprecated, or simply one of three supported choices. Tab order and a redirect
are not a statement of intent, and no such statement was read. Answering that is
the first step here, not picking a variant.

The immediate practical cost is a trap: **checking the port against the docs site
now compares it to a different library by default.** Anyone reaching for
"upstream says…" has to select the Radix tab first.

Select is reported to differ between the two variants as well. What was checked
here is only the Radix side, and the port matches it: with `apple, banana,
blueberry, grapes, pineapple`, pressing `g` then `p` inside one second searches
`"gp"`, matches nothing and stays on grapes, while `p` after the 1s buffer
expires reaches pineapple — now covered by "stays put when the accumulated search
matches nothing" in `spec/system/select_spec.rb`. **What Base UI does instead was
not measured**: the docs demo's panel closed on every click attempt, by mouse and
by keyboard, and driving it was abandoned rather than guessed at.

## Smaller things

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
- [ ] **Two previews claim `<label for>` cannot name a `<button>`.**
      `switch/previews/default.html.erb` and `field/previews/default.html.erb`
      both say so, and it is exactly the misconception
      [04-bugs-fixed.md](decisions/04-bugs-fixed.md) exists to correct — a
      button is a labelable element. `checkbox`'s own preview relies on the
      opposite and passes axe. Previews are documentation, so this is a
      falsehood the gem ships.
- [ ] **`typeahead.js` searches over items where Radix's *menu* searches over
      strings.** The algorithm matches `getNextMatch`
      (vendor/radix/ui/menu.tsx:1336-1347); the input does not — though only in
      the menu. `findNextItem`, the select's copy this was ported from
      (select.tsx:1906-1921), is handed items and compares them by identity,
      which is what the gem does. The menu passes `values: string[]` and maps the
      winner back with `items.find(i => i.textValue === nextMatch)`
      (menu.tsx:451-454), so two items sharing a label are *one* candidate to
      it. With `["Copy", "Copy", "Delete"]` and the second Copy current,
      `values.indexOf(currentMatch)` resolves to index 0, the
      single-character filter drops both Copies, and Radix does not move; the
      gem compares element identity and cycles to the first Copy. Arguably the
      better behaviour — deciding that is the work here, not writing the code.
      Either match Radix (search over `textContent` strings, then map back) or
      keep the divergence and say so where it is asserted: the comment in
      `typeahead.js` and the one above "cycles to the next match when a
      character repeats" in `spec/system/dropdown_menu_spec.rb` now
      claim only that the two Radix *bodies* agree, which is all that was ever
      verified.
- [ ] **An aliased icon name cannot be registered over.** `icon/component.rb:54`
      resolves `ALIASES` in the constructor, so `#name` is already `"ellipsis"`
      or `"loader-circle"` by the time `#path` reads the registry:
      `register("more-horizontal", …)` and `register("loader-2", …)` are stored
      under keys nothing ever looks up, and the bundled drawing renders. That
      is the same shape as the override bug fixed in the same wave — a host
      instructed the gem and the gem carried on — narrowed to the two aliases.
      It is not hypothetical from the inside either: the gem itself renders
      `Icon::Component.new("more-horizontal")` in
      `pagination/ellipsis/component.rb:21` and
      `breadcrumb/ellipsis/component.rb:21`, and `Spinner::Component` passes
      `"loader-2"` to `super`. The fix is to try the unaliased name in the
      registry before aliasing, or to alias on write in `IconRegistry.register`
      — the second also makes `registered` reflect what a host asked for, and
      wants a spec for each alias.
- [ ] **The typeahead buffer survives a close.** Radix's menu clears its search
      buffer on blur (vendor/radix/ui/menu.tsx:585-590) and Select exposes
      `resetTypeahead` for the same purpose (vendor/radix/ui/select.tsx:1877);
      `Typeahead` only clears on its own 1s timer. Open a dropdown, press `s`,
      Escape, reopen and press `a` inside that second: the gem searches `"sa"`
      and stays put where Radix searches `"a"` and moves. A `reset()` on
      `Typeahead` called from each controller's `onClose` closes it; a system
      spec has to press the two keys inside one second, so it needs the timer
      controlled rather than waited out. Self-heals after a second, which is
      why it has gone unnoticed.
- [ ] **A hand-written element carrying a `data-shadcn--*-target` gets no
      ARIA.** The controllers used to backfill `role`, `aria-haspopup` and the
      rest at connect; that was deleted once the components were emitting all
      of it server-side (commit `4e88573`). The components remain correct — but
      a host who writes their own trigger markup with the target attribute
      instead of rendering the component now silently gets an element with no
      role and no `aria-expanded`. Nothing in the README says the attributes
      are the component's job rather than the controller's. One sentence under
      the JavaScript section closes it; the alternative, backfilling again,
      is what that commit deliberately undid.
- [ ] **Nothing routes a reader to `vendor/radix/`.** Its own README is good and
      names its staleness risk, but only someone already inside the directory
      reads it. `CLAUDE.md`'s map now lists it; `.claude/docs/` still does not
      mention it anywhere, and `decisions/03-testing.md` — which says what each
      reference is worth — is where the distinction belongs: `vendor/shadcn/`
      is policed by `parity_spec` on every run, `vendor/radix/` is policed by
      nobody and can go stale the moment Radix ships past `REVISION`.
- [x] **`icon.rb`'s two comments disagreed with each other** — the header said no
      autoloadable constant resolves in an initializer, and the comment on the
      delegating `.register` fifteen lines below still called it what a host
      calls "once, at boot". The lower one now names the same constraint.
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
