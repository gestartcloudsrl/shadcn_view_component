# TODO

Ordered by what blocks a release, then by value. Rationale for anything already
decided is in `decisions/`.

The dummy serves two full pages a Lookbook preview cannot give: `/sidebar` and
`/chat`. Both double as system-spec fixtures — `/chat` is where the message
scroller's load behaviour is asserted, because it is the realistic case.

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

- [x] **Reverse parity.** `spec/reverse_parity_spec.rb` compares the classes
      rendered on each `data-slot` against the whole vendored corpus. Took three
      designs; the two that failed and the trade the third makes are in
      [decisions/03-testing.md](decisions/03-testing.md).
- [ ] **A screen-reader pass.** axe covers names, roles, required parents and
      contrast. It does not tell you whether the experience makes sense in
      VoiceOver or NVDA — for a library whose pitch is Radix's accessibility,
      that is the claim least tested, and it cannot be automated: it needs a
      person and assistive technology.

      Where to spend the hour, in descending order of how likely each is to be
      wrong:

      1. **The searchable select** (`select/previews/searchable.html.erb`). The
         newest pattern in the gem and the only one using virtual focus —
         `aria-activedescendant` on the field while DOM focus never moves.
         Listen for whether the active option is announced as the arrows move,
         and whether filtering to nothing says anything at all: there is no
         `aria-live` region, deliberately, and upstream has none either.
      2. **Select, Checkbox and Switch**, which are `<button>`s carrying an ARIA
         role — `default_tag :button` plus `role: "checkbox"` and
         `role: "switch"` respectively. The FormBuilder points a name at each;
         a bare component has nothing. Confirm the name is heard. On the
         **plain** select (`previews/default.html.erb`) the trigger is
         `role="combobox"`, and whether that reads sensibly on something not
         editable is the question; the searchable one's trigger carries no role
         at all, so listen to both.
      3. **The dialog and sheet**, for focus return and whether the exit
         animation's window leaks anything — `inert` is set while an exit is
         deferred, and the reasoning is in
         [decisions/02-javascript.md](decisions/02-javascript.md).
      4. **The accordion**, whose collapsing panel is deliberately exempt from
         `inert` and stays interactive while it closes.

      Anything found here is worth more than another automated check: axe has
      been run over every family, at rest and with each layer open, and it is
      green.
- [x] **The select's scroll-button auto-scroll.** Covered, once the pointer was
      driven through Chrome's own input pipeline rather than WebDriver's Actions
      API — see [decisions/03-testing.md](decisions/03-testing.md).
- [x] **`transform`/`filter`/`contain` ancestors.** Reproduced and measured:
      `spec/system/containing_block_spec.rb` opens a popover inside each of the
      three and asserts it still lands centred under its trigger. It does — the
      top layer covers this too, not only what paints over. Removing the
      promotion drops the panel 82, 176 and 270 pixels, one figure per ancestor,
      which is what a containing-block failure looks like.

## Components not ported (14)

All 27 unported sources were vendored, so this list is derived from what they
actually import rather than from memory, and `spec/parity_spec.rb` holds it as
`not_yet_ported` and fails if the two drift. Eleven have since been ported —
`empty`, `button-group`, `input-group`, `item`, `sidebar`, the four markup-only
ones (`message`, `bubble`, `attachment`, `marker`), `message-scroller`,
`hover-card`, `direction` and `scroll-area` — leaving 14.

The grouping this replaced was wrong in four ways, each recorded below. A fifth
error was mine, and is recorded with the group it belongs to.

- **Markup only** (0 left): `message`, `bubble`, `attachment` and `marker` have
  shipped — 22 parts, no controller, no event handlers.
  *The classification held on behaviour and understated the rest. Three of the
  four carry cva variants, `attachment` restamps `Button`, and `attachment`
  also reaches for three utilities that are shadcn's own CSS rather than
  Tailwind's — `shimmer`, `scroll-fade-x`, `scrollbar-none` — which no vendored
  source here defines. They were read from the stylesheet ui.shadcn.com serves
  and are now at the end of `shadcn.css`, which is the only hand-written CSS in
  this gem with nothing local to diff it against.*

  *`input-group` was in this group and should not have been.* It has an
  `onClick` on its addon — clicking the addon focuses the group's control — so
  it needed a Stimulus controller and a system spec. The classification missed
  it because it was reached by grepping for React hooks and not for inline
  event handlers. All eight candidates were re-checked with the right
  instrument afterwards; `input-group` was the only one affected.

- **Radix behaviour to reimplement in Stimulus** (4): `slider` (63),
  `navigation-menu` (168), `context-menu` (252), `menubar` (276).
  *`scroll-area` has shipped, and it is the sharpest case yet of the line count
  in this list measuring the wrong thing: 58 lines of shadcn over 1,189 of
  Radix. Most of that did not survive — the layout is CSS, and the controller
  computes two numbers per axis. Take these four numbers as the size of the
  markup, never of the work.*
  *`direction` (22) has shipped and turned out to be a different shape from the
  rest of this group: shadcn's file wraps Radix's `DirectionProvider`, which is
  a React context and renders no DOM, so there was no component to port. What
  there was to port was the *consequence* — nothing in this gem's JavaScript
  read reading direction at all, and three controllers' arrow keys depend on
  it. `parity_spec` grew a third list for it, `no_markup`, because a component
  with no classes cannot be compared against any.*
  *`hover-card` (44) was the smallest and has shipped. It cost almost no new
  machinery — `floating.js` and `dismiss.js` already existed — and what it
  needed instead was reading Radix's source for two behaviours the shadcn file
  cannot show: every tabbable inside the card leaves the tab order, and the
  card stays open while text in it is selected. The first is ported; the second
  is not, and is recorded in features/README.md.*
  *Six of these were filed as "plain ports, no blocker". They are the same class
  of work as `dropdown_menu` and `select` — roving focus, typeahead, submenus,
  drag — not the same class as `badge`.*

- **Blocked by a third-party npm package** (9): `drawer` (vaul), `chart`
  (recharts), `command` (cmdk), `carousel` (embla-carousel-react), `input-otp`,
  `sonner` (+ next-themes), `resizable` (react-resizable-panels), `calendar`
  (react-day-picker), `combobox` (**@base-ui/react**).
  *`message-scroller` was in this group and has shipped. The package it depends
  on turned out to be MIT, dependency-free and in `shadcn-ui/ui` — the repo this
  gem already vendors from — so it was vendored to `vendor/shadcn-react/` and
  reimplemented against it rather than treated as a blocker. Prepend anchoring
  is the one piece still unwritten; see
  [features/message-scroller.md](features/message-scroller.md).*
  *Two of these were not recorded as blocked at all. `combobox` has moved off
  Radix to Base UI, so reimplementing it means tracking a second headless API
  rather than the one already understood; `message-scroller` depends on a
  package shadcn publishes itself. `drawer` was filed as a plain port and is
  vaul.*

- **A case of its own** (1): `form` is react-hook-form, and the Rails answer is
  the FormBuilder that already exists plus `field`, already ported — so it may
  be a question already answered rather than a port.
  *`sidebar` was the second entry here and has shipped: all 23 renderable parts,
  the open state and its cookie, `cmd/ctrl+b`, the menu button's `tooltip:`, and
  a mobile branch with the Sheet's backdrop and slide. The twenty-fourth export
  is `useSidebar`, a React hook whose job here is the Stimulus controller. See
  [features/sidebar.md](features/sidebar.md) and
  [decisions/02-javascript.md](decisions/02-javascript.md).*

The old list said "command/combobox" on one line. They are two files upstream,
which is why the total was 27 and not 26.

Most wanted in a real Rails app, roughly: command, calendar, sonner, combobox,
slider — which is, awkwardly, five of the eleven hardest. `sidebar` was on this
list and has shipped.

Filtering is no longer wholly behind them: `Select::Component.new(searchable: true)`
ships a filterable select, built rather than ported since no Radix-based shadcn
select has one. `command`'s palette and `combobox`'s free-text entry are still
unported and still blocked on npm — a filter over options already rendered is a
smaller thing than either.

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
as behaviour, which Radix also does (vendor/radix/ui/menu.tsx:585-590). Two
independent upstreams agreeing is what moved that from a curiosity to a gap;
it is the now-closed "typeahead buffer survived a close" entry below.

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

## Do not compare the look against the docs site

Measured 2026-08-09 while checking the message scroller's buttons: the live
demo's button computes to `rounded-2xl` with a 1px border, and this port's to
`rounded-md` with none. Neither is wrong. The docs page serves the **Base UI**
registry, whose Button is a different component from `new-york-v4`'s — the
variant order recorded above, showing up as a visual difference rather than a
behavioural one.

So the rule in `CLAUDE.md` — open upstream's example and read what it renders —
holds for *shape*: which parts nest where, which element owns which attribute.
It does not transfer to **appearance**, because the appearance on that page
belongs to a registry this gem does not port. Check a class string against
`vendor/shadcn/ui/`, not against a screenshot.

## The registry moved, and this gem ports the older one

Found while looking for the searchable select's source, 2026-08-08.

shadcn now authors components as **bases** (`base`, `radix`, `aria`) crossed with
**style token sheets** (`nova`, `sera`, `vega`, …), and the generated components
carry semantic `cn-*` classes whose rules live in those sheets.
`apps/v4/registry/README.md:16` calls `new-york-v4` — the registry this gem ports
— "the legacy source registry".

Measured rather than inferred: `new-york-v4` and `bases/radix` hold 61 components
each, differing by one in each direction (`questionnaire` there, `form` here),
and `select.tsx`, `dropdown-menu.tsx`, `button.tsx` and `card.tsx` are
byte-identical to the copies in `vendor/shadcn/ui/`. The changelog says "Radix is
not being deprecated. We still support it, and every update and new component
will ship for both libraries." So: **frozen, not abandoned.**

Not established: whether `new-york-v4` will keep pace. That is the open question,
and it is not answerable from the repository.

What following the new architecture would cost: adopting `cn-*` plus the style
sheets that define them, which is a different gem from this one — every class
string here is a Tailwind utility, and `parity_spec` compares utilities. Worth
noting that it would not have delivered the component that raised the question:
`bases/radix` has no searchable select either.

## Smaller things

- [ ] **The Sidebar's mobile sheet has no role and no accessible name.** It
      traps focus, locks scroll and dims the page behind it — everything a modal
      does — while announcing nothing. Upstream's is a Radix Dialog, so it
      carries `role="dialog"`, `aria-modal` and a screen-reader-only
      `SheetTitle`/`SheetDescription`: *"Sidebar"* and *"Displays the mobile
      sidebar."* (`vendor/shadcn/ui/sidebar.tsx:198-201`). Nothing here does.
      `accessibility_spec` cannot see it: the sidebar preview is only ever
      exercised at desktop width, where there is no sheet. Whatever fixes it
      should add a mobile case there at the same time.
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
- [x] **The typeahead buffer survived a close.** `Typeahead#reset` now exists and
      each controller calls it at *its own* moment, because Radix does not use
      one: the select resets **on open** — its own comment reads "reset typeahead
      when we open" (vendor/radix/ui/select.tsx:331-336) — while the menu clears
      **on blur**, when focus leaves the content
      (vendor/radix/ui/menu.tsx:585-590). This entry used to claim
      `resetTypeahead` existed "for the same purpose" as the menu's blur; it did
      not, and following that would have put the select's call on the wrong
      event. `handleOpen` is its only caller.
      The gem's menu resets in `onClose`, which is where the focus it owns
      actually leaves — nothing listens for `focusout`, so a menu losing focus
      *without* closing would keep its buffer where Radix's would not. No path
      in the gem does that: Tab, Escape and an outside click all close first.
      Both specs disable the 1s expiry that `typeahead.js:32` schedules, so the
      reset is the only thing that can explain an empty buffer rather than the
      example racing Capybara.
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
- [x] **Nothing routed a reader to `vendor/radix/`.**
      `decisions/03-testing.md` now carries "What the two vendored references
      are worth": `vendor/shadcn/` is policed by `parity_spec` on every run,
      `vendor/radix/` by nobody. It also records the sharper point that came out
      of using them — reading either one correctly still answers "what does the
      vendored version do", never "what does upstream do today" — and the
      control-measurement rule that two void readings this session earned.
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

- **Falling back to the last character when the typeahead buffer matches
  nothing.** Type `g` then `p` inside a second and the search is `"gp"`, which
  matches nothing, so the keystroke is discarded — it *feels* like having to
  wait a second between letters. Retrying with just `"p"` would fix it and
  could only affect a branch that currently does nothing at all.
  Measured on both upstreams before deciding, in the same list and the same
  way: shadcn's Radix select stays put, and Base UI's own demo (Gala, Fuji,
  Honeycrisp, Granny Smith, Pink Lady) lands on **Gala** for a fast `gp` — the
  `g` moves, the `p` is swallowed. `gr` reaching Granny Smith on both was the
  control, so this is "the key is ignored", not "the keys never arrived".
  The objection worth taking seriously is that matching upstream does not make
  it good — a swallowed keystroke reads as a bug to someone who does not know a
  buffer exists. That argument stands or falls on the *native* `<select>`, which
  is where a user's expectation actually comes from, so it was measured too: on
  the gem's own `native_select` preview (Apple, Banana, Blueberry), `bl` reaches
  blueberry and a fast `ab` **stays on apple**. Chrome on macOS; other engines
  not checked.
  Three independent references agreeing — including the platform control — makes
  this the typeahead contract rather than an oversight to correct. And the
  clincher is local: this gem ships `shadcn_select` *and* `shadcn_native_select`
  and recommends the latter, so adding the fallback would make two selects in
  one form answer the same keystrokes differently. The 1s window is hardcoded
  upstream too (vendor/radix/ui/select.tsx:1871) and exposed as no prop.
