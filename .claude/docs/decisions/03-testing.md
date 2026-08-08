# Testing decisions

What each spec is for, what it deliberately does *not* prove, and which
approaches were measured and rejected.

## The parity spec was theatre

Two council members proved it by mutating code that stayed green. It compares
token *sets per family*, so a class sitting in a comment counted as ported, and
swapping two variants' bodies passed cleanly.

Three responses, in order of value:

1. **`snapshot_spec.rb`** — golden HTML for every preview. Catches wrong part,
   wrong variant, attribute drift, extra classes. Verified against a real variant
   swap: parity passes, snapshots fail.
2. **Ripper instead of a regex** for the Ruby side of parity, so a class in a
   comment can no longer count as ported.
3. **The README claim was corrected.** Overstating what a test proves is worse
   than the gap itself.

Parity still runs **one way**: when upstream removes a class the port keeps it
and nothing fails.

## What the parity list assertion proves, now that sources arrive early

All 27 unported components are vendored, so `vendor/shadcn/ui` no longer holds
only what has been ported. The example that used to assert the two lists were
*equal* now asserts that `ports` and `not_yet_ported` account for the vendored
set between them.

That keeps the signal worth having — vendoring a TSX without deciding which side
it belongs on still fails — and it was verified by adding a stray file and
watching it fail by name. What it gives up is the reason the equality existed:
nothing now stops a component sitting vendored and unported indefinitely, which
is the state 23 of them are in on purpose.

The list also has to be *maintained in two places by hand* — here and in
[todo](../todo.md) — and only the spec's copy is enforced. The prose copy can
drift, and did, within one working day: `input-group` was filed as markup-only
after a grep for React hooks missed its inline `onClick`.

## The reverse parity check was rejected

Classes-the-port-has-that-upstream-doesn't was measured first: 12 of 13 families
came back dirty with false positives — Ruby constant names, icon names, slot
names, legitimate composition where one family reuses another's parts. It would
have needed exactly the exception tables that were being criticised in the first
place. Snapshots cover the same ground properly.

## `stimulus_contract_spec.rb`

The best coverage-per-line in the repo. Ruby and JS are wired together by bare
strings, so renaming a controller method breaks every Select in the wild with
nothing failing. Static analysis of the JS, not execution of it.

## `reduced_motion_spec.rb`

Reads the *compiled* bundle. What it reads is always fresh rather than
whatever a previous run left on disk, but the freshness comes from
`spec_helper.rb`'s suite-wide `before(:suite)` hook, not from this spec — it
used to build the bundle itself in a per-file `before` hook, but
`config.order = :random` meant that hook could run *after* the specs that
read the bundle, which then asserted against whatever the previous run had
left on disk; moving the build to a suite-wide hook that always runs first
removes the ordering hazard. It asserts the
`@media (prefers-reduced-motion: reduce)` block for every
`animate-*` class the components actually apply — scanned off
`app/components`, not typed out — and
that the accordion pair carries `!important` there. That last part is the point:
without it Tailwind's own `animate-*` utility resets the duration, and a
`@media` block missing the flag is indistinguishable by inspection from a
working one.

Rule text, not behaviour — see
[what is still unverified](#what-is-still-unverified).

## Two ways the snapshot suite can stop asserting

Both are silent, which is what makes them worth writing down.

**`SNAPSHOTS=overwrite` turns the suite into a writer.** In that mode
`snapshot_spec` regenerates the goldens instead of comparing against them, so
every example passes while checking nothing. That was harmless while
`previews_spec` existed, since it had no such mode and would still have caught a
preview that raised; deleting it made the exposure real. `snapshot_spec` now
carries an `if: ENV["CI"]` context that fails when the variable is set on CI.
Local use stays working, because reading the regenerated diff before committing
it is the point of the flag.

Note the shape: the guard is an *example*, not a `raise` in the describe body. A
raise there kills the run during loading, before anything can report why — the
mistake `reduced_motion_spec` had already made once.

**A new generated id makes every snapshot containing it differ per run**, unless
the normaliser is widened with it. Generated ids follow
`shadcn-<thing>-#{SecureRandom.hex(4)}`; the regex that flattens them lives in
`snapshot_spec` and has to name each prefix. Miss one and the failure is
*nondeterministic*, so the first person to see it re-runs and gets a different
answer. Two consecutive plain runs is the check — one cannot tell a working
normaliser from a lucky hex.

## System specs

The only place the JavaScript executes. Previews double as fixtures, which is why
adding a preview is what gets a component covered.

Two of the fixed bugs were deliberately re-introduced to confirm the specs catch
them.

Three things to know before writing one:

- The gallery layout carries its own ModeToggle and ThemeSelector, so a preview's
  dropdown or select is **not** the only one on the page.
- Clicking an overlay element does not work — Selenium aims at its centre, which
  is where the dialog sits. `click_outside` clicks a viewport corner instead.
- Turbo paints the cached snapshot before the fresh body; asserting during that
  preview is a race. `wait_for_turbo` waits for the `data-turbo-preview` marker
  to clear. One spec was flaky 1-in-5 before this.

## Asserting on an animation

The suite suppresses animations twice over, and both settings are right for
every other spec: the driver runs Chrome with `--force-prefers-reduced-motion`,
and `Capybara.disable_animation` makes Capybara's own server inject
`*, ::before, ::after { … animation-duration: 0s !important; … }` into every
page it serves.

`exit_animation_spec.rb` forces a duration back onto the elements under test
(`force_animations`) rather than registering a second driver. Only the duration
is overridden; `animation-name` still comes from the component's own class, so
what the assertions read is the shipped code and not the harness.

**How it wins is the interesting part, and it changed once already.** Capybara's
rule is `!important` at specificity zero, so beating it takes an `!important` of
its own **and** more specificity — neither alone is enough, since no ordinary
declaration outranks an important one however specific it is. Beating the *gem's
own* `!important` on the accordion utilities needs more still, because
[the cascade-layer trap](02-javascript.md#the-one-css-trap-worth-remembering)
inverts for `!important` declarations: a layered `!important` beats an unlayered
one at any specificity, so an injected `<style>` cannot touch it. The helper
therefore sets the property **inline, with `!important`**, which is the only
thing that outranks a layered `!important` short of another layer. Drop that
flag from the helper and nothing is forced at all: every element falls back to
Capybara's `0s`.

That was not theoretical. When the accordion first shipped its `!important`, the
harness was silently disarmed and two examples became races that passed about
half the time — and the round that found it first concluded the flakiness was
pre-existing, having compared against a baseline that already carried the bug.

The assertions themselves read what the browser **scheduled**
(`getAnimations()`), never what is on screen at a given moment. That is what
makes them deterministic — either the animation started or it did not.

Three traps, each of which cost a review round:

- **`have_no_css` is a visibility predicate**, so it is unsound as a landing
  gate for anything that animates a *height* or *width*: the box reaches zero
  size before the JavaScript teardown runs. Gate on the `hidden` attribute
  instead.
- **Assertions on presence do race**, even though assertions on scheduling do
  not. `have_css` retries for presence, so an example is relying on the forced
  duration outlasting a Selenium round trip. A moment-in-time property read is
  the same shape.
- **A zero-duration animation is no animation at all.** Capybara's rule leaves
  `animation-name` alone, but zeroing the duration is enough on its own:
  `getAnimations()` on an element whose only animation resolves to `0s` comes
  back **empty**, so `ExitQueue.defer` takes its *synchronous* branch and never
  sets `data-exiting`. Measured in this harness, by patching
  `Element.prototype.getAnimations` and closing a popover and a dialog under
  the ordinary suite settings: both reported `animation-name: exit`,
  `animation-duration: 0s`, and an empty list. So the rest of the suite
  exercises the synchronous branch, not the deferred one.

  **The accordion is the exception**, for the same reason `force_animations`
  has to go inline: its reduced-motion override is `!important` inside
  `@layer utilities`, which outranks Capybara's unlayered `!important`, so the
  shipped `0.01ms` really applies. At `0.01ms` the animation *is* returned and
  its `playState` *is* `"running"` — measured the same way — so an accordion
  collapse takes the deferred branch even in a spec that asked for nothing of
  the sort, which is what `disclosure_spec.rb`'s collapses do.

  The deferred branch is otherwise reached only where a spec forces a duration:
  most of the closes in `exit_animation_spec.rb` call `force_animations` on the
  element they drive, plus `turbo_spec.rb:78` ("flushes a layer's exit before
  Turbo caches the page"), which forces 2s onto the select.

  The one close in `exit_animation_spec.rb` that does not is "tears down
  without waiting at all", under "a layer carrying an animation that never
  ends" — deliberately: it exists to show the *synchronous* branch still runs
  with no forced duration in play. Its added animation is infinite, so
  `willEnd` filters it out the same as it would the shipped `animate-out`'s
  own 0s, and `ExitQueue.defer` never sets `data-exiting` at all.

## axe

Runs over every family, at rest and with each layer open, plus contrast in dark
mode. Worth remembering: three of the first 13 "failures" were my own spec bugs —
the rule is `color-contrast` not `color_contrast`, and `button` had no `default`
preview. **A red axe run is not automatically a product bug.**

The genuine finding was that Select, Checkbox and Switch had no accessible name;
see [bugs-fixed](04-bugs-fixed.md).

## The pass against rspec-conventions

Applying the [skill](../../skills/rspec-conventions/SKILL.md) to every spec was
mostly restructuring — contexts instead of conditions in descriptions, setup
lifted out of repeated examples — but four assertions turned out to prove less
than they read like, and one gap was filled:

- **`button_spec`'s variant and size loops** asserted only that `data-variant`
  echoed its argument, which is written by `element_attributes` and never
  touches the style block. 14 examples for one line. They now name the class
  that distinguishes each variant; mutating a class string fails them, and did
  not before.
- **`smoke_spec`'s `have_css("[data-controller]")`** was satisfied by the
  gallery layout's own ModeToggle and ThemeSelector on every page, so it passed
  whatever the family did. It now asserts the family's own identifier.
- **`parity_spec` and `stimulus_contract_spec` went green when their extractors
  broke.** Nothing extracted means nothing missing. Both now have a tripwire;
  breaking the TSX tokenizer or the action scan fails loudly instead of quietly
  dropping 41 examples.
- **The FormBuilder's `aria-labelledby`** — the fix for the accessible-name bug —
  had no test at all. Removing it from `shadcn_switch` now fails one example.

Two lists became derived rather than typed: the accessibility audit reads the
preview families off disk (which added `aspect_ratio`, and covers anything added
later), and the smoke spec derives its families from the controllers directory.

One correction while doing it: **`<label for>` does name a `<button>`** — button
is a labelable element, so `ThemeSelector`'s original id-and-`for` trigger
worked and axe accepted it. It has since been switched to `aria-labelledby` to
match the FormBuilder — the label was `sr-only`, so `<label for>`'s only
advantage, click-to-focus, was not buying anything.

## What the two vendored references are worth

`vendor/shadcn/` is checked on every run: `parity_spec` reads it, so a drifted
copy fails the suite. **`vendor/radix/` is policed by nobody.** No spec reads it
— its own README says so — and it can go stale the moment Radix ships past the
commit in `REVISION`. It is a citation source, not a fixture.

Neither answers the question people actually ask of them. Both are a snapshot of
*what was vendored*, and the interesting question is usually *what upstream does
today*, which is a different one.

That distinction cost a real regression. The dropdown's wrap-around was removed
citing three files that all agreed — `menu.tsx:387` and
`roving-focus-group.tsx:117` both destructure `loop = false`,
`roving-focus-group.tsx:324-326` is the branch that acts on it, and
`vendor/shadcn/ui/dropdown-menu.tsx` never passes it. Every citation was
accurate, and the conclusion was still wrong in practice, because
`ui.shadcn.com/docs/components/dropdown-menu` now **redirects to a Base UI
variant** whose menu wraps by default. No amount of re-reading the vendored
files could have surfaced that: they answer "what does the Radix version do",
and the question was "what does a person see when they check".

So: a claim about **what this port must match** is settled by reading
`vendor/`. A claim about **what upstream does** is settled by opening it. When
they are the same sentence, they are still two claims.

And a third case, which is neither: **choosing a shape is not a claim to check
but a decision to make, and the example decides it.** The searchable select was
argued between two candidate structures worked out here from the parts already
measured — input, listbox, options. Upstream's answer was neither: a
`role="dialog"` popover holding a separate listbox, which dissolves the argument
rather than settling it. The deciding element was simply one nobody had looked
at. `CLAUDE.md` carries this as a working rule; it is recorded here because the
failure looks like diligence — every measured part was measured correctly.

### Run a control, every time

Driving a real page, "the component ignored my keystroke" and "the keystrokes
never arrived" produce identical readings. Two measurements in one session were
void for exactly that: keys typed at a select whose panel had silently stayed
closed, and keys typed at an element focused *inside* an iframe while the
top-level document held focus. Both looked like a confirmed no-op.

The fix is cheap and non-optional: before measuring the case in doubt, measure a
case that must succeed. `bl` reaching blueberry proves the keys land, so a
following `ab` that does nothing means something. Assert the precondition too —
that the panel is open — rather than inferring it from the result.

The same trap has a written form, and it is worse because it survives review:
**the driver produces the result the example is looking for.** Three attempts at
covering the select's scroll-button auto-scroll passed with the feature
neutralised, because Selenium moves an element into view before pointing at it
and the button was then the last child of the scrolling element — reaching the
end of the list proved only that Selenium had scrolled. An example that passes
under mutation is worse than no example: it is a claim of coverage that is not
there. Mutate every new system spec before trusting it.

### `be_visible` does not wait; `have_css` does

`expect(element).to be_visible` reads the state once and never retries, so any
example asserting a state some event is about to change is racing it. Two
scroll-button examples did, passed every local run and two full suites, then
failed during a merge verification. `have_css(selector, visible: :visible)` and
`visible: :hidden` wait, and cannot race.

Repeated green runs are not the argument for the fix — the racing version was
green repeatedly too. The argument is structural: a waiting matcher cannot lose
the race, and the other form can.

### What a system spec cannot see

It reads the DOM, so it sees attributes, text and structure. It does not see
**appearance**. A change that swaps how something is indicated — DOM focus for
`aria-activedescendant`, say — leaves every attribute assertion green while the
component goes blank on screen; that is [a bug this repo
shipped](04-bugs-fixed.md). `getComputedStyle` is available through
`evaluate_script` and is the only instrument here that would have caught it.
Reach for it whenever the thing under test is *shown* rather than *recorded*.

## What is still unverified

- Parity in the removal direction (above).
- A screen reader. axe covers names, roles, required parents and contrast; it
  does not say whether the experience makes sense in VoiceOver or NVDA.
- **What the reduced-motion CSS does once it renders.**
  `reduced_motion_spec.rb` covers the compiled rules themselves, `!important`
  included. What nothing covers is the rendered result. Capybara's own
  `animation-duration: 0s !important` overrides the `0.01ms` for every one of
  these utilities except the accordion pair, whose `!important` is layered and
  survives — so the accordion is the only place the suite even *runs* at a real
  reduced-motion duration, incidentally rather than because a spec asked, and
  nothing asserts the duration there either.
- **`flushAll()` in a controller's `disconnect()`.** There is no JavaScript unit
  harness here, and a system spec cannot tell a synchronous flush from a
  microtask-later one via the promise rejection that DOM removal triggers
  anyway.
- **Whether an exit animation looks right.** The specs assert an animation of
  the expected name was scheduled and that the element eventually leaves. They
  say nothing about duration, easing, or whether an exit reads as the reverse of
  its entrance.
- **The select's scroll-button auto-scroll.** Which chevron is offered, and that
  they stay pinned while the options move, are covered. The 50ms interval behind
  them is not: Selenium's pointer does not reach those buttons by any route
  tried — neither `move_to` nor `click_and_hold` moves the list a pixel — while
  a `PointerEvent` dispatched from the page scrolls it at once, so the handler
  is right and the driver is the obstacle. Verified by hand instead, in a real
  browser: `scrollTop` 88 → 120 over 300ms. Dispatching that event from
  `execute_script` would go green and prove almost nothing, so it was left
  undone rather than faked.
