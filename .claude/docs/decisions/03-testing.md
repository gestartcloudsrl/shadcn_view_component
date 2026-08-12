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

**A false positive is an extractor bug until proved otherwise.** `parity_spec`
holds an `allowed_missing` list, which is the obvious place to send anything it
reports wrongly — and the wrong one. Porting the carousel, it named `/>` as a
class the port had dropped: the string
`"useCarousel must be used within a <Carousel />"` tokenizes into something with
a slash in it, and every real Tailwind utility has a letter. The fix went into
`class_like?` (`spec/support/shadcn_source.rb:91`), not into the list. An entry
in `allowed_missing` silences one file forever; a tokenizer that admits
punctuation goes on lying about the rest.

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

## Reverse parity took three designs

`reverse_parity_spec.rb` exists now. Two earlier attempts do not, and why they
failed is what shaped the one that shipped.

**Per-family token sets from Ruby string literals** — 12 of 13 families dirty.
`select-item`, `chevron-down` and `more-horizontal` are all shaped like Tailwind
utilities, so slot names, icon names and constants counted as classes.

**Per-slot, against the slot's own TSX file** — 56 of 145 slots dirty, every one
the same shape: upstream writes `<DialogTrigger asChild><Button …>`, so Button's
classes land on `dialog-trigger` while living in `button.tsx`. Untangling that
needs a table of which component wraps which — the exception table whose absence
was the point of the criticism.

**What shipped** compares the classes rendered on each `data-slot` against the
*whole* vendored corpus, `examples/` included. Composition stops being a false
positive, because Button's classes are in the corpus wherever they land. 15
slots came back with extras and every one had a reason, in three groups: sizing
a preview passes as a caller, the searchable select's own classes, and the
`lucide lucide-*` pair `Icon::Component` stamps where upstream mounts a React
component. They are listed in `OURS`, with the reasons.

The trade, stated plainly: it catches a class only when it survives **nowhere**
upstream, which is narrower than per-slot would have been. It does catch the
thing it was built for — deleting `group/alert-dialog-content` from
`alert-dialog.tsx` fails it by name. Reading the snapshots is also what makes
`OURS` carry preview classes: a preview is a caller, and callers may add
classes, so a new preview with a width in it will fail this spec until the width
is listed.

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

Four things to know before writing one:

- The gallery layout carries its own ModeToggle and ThemeSelector, so a preview's
  dropdown or select is **not** the only one on the page.
- Clicking an overlay element does not work — Selenium aims at its centre, which
  is where the dialog sits. `click_outside` clicks a viewport corner instead.
  When the overlay itself is the target — the sidebar sheet's backdrop is what
  a user taps to close it — `click(x:, y:)` offsets from that centre to a part
  of it nothing covers.
- Turbo paints the cached snapshot before the fresh body; asserting during that
  preview is a race. `wait_for_turbo` waits for the `data-turbo-preview` marker
  to clear. One spec was flaky 1-in-5 before this.
- **`stimulus_contract_spec` makes "markup now, behaviour later" impossible.**
  The moment a component names a controller, a target or an action, that spec
  fails until the JavaScript declares it. So a component with behaviour is one
  slice, not two — worth knowing before planning to land its markup first, which
  is what the message scroller's plan assumed and had to abandon.
- **A failure that only appears in a full run may be leaked global state, not
  flake.** `dismiss.js` keeps one layer stack for the page, and a sheet whose
  outside-click had been broken never popped its own layer. Ten examples across
  `overlays_spec` and `select_spec` failed in `rake` and passed file-by-file.
  Before hunting a race, check whether an earlier example left something on a
  module-level stack.

## Asserting on an animation

The suite suppresses animations twice over, and both settings are right for
every other spec: the driver runs Chrome with `--force-prefers-reduced-motion`,
and `Capybara.disable_animation` makes Capybara's own server inject
`*, ::before, ::after { transition: none !important; animation-duration: 0s
!important; animation-delay: 0s !important; scroll-behavior: auto !important }`
into every page it serves. The first of those four is not the same kind of thing
as the others and has its own subsection below.

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

### A transition is not an animation, and the harness deletes it outright

Everything above is about keyframes. Capybara's injected rule
(`capybara-3.40.0/lib/capybara/server/animation_disabler.rb:64-71`) also carries
`transition: none !important`, and that is a stronger thing than the `0s` it does
to animations: `none` removes the transition **property**, so forcing a duration
back changes nothing — the property has to come back too.
`spec/system/toaster_spec.rb` sets `transition: all 2s` inline with `!important`,
which is `force_animations`' trick with one more thing restored.

The consequence is the same as for a zeroed animation and arrives by the same
route: `getAnimations()` returns transitions as well, so with them removed
`ExitQueue.defer` finds an empty list and takes its synchronous branch. An
element whose exit is a *transition* therefore leaves the DOM in the tick it was
closed, everywhere in this suite except where a spec hands the property back.

One component is affected today: the toaster is the only closing element here
built on a transition (`data-[state=closed]:opacity-0`) rather than on
`animate-out`, which the other sixteen use. It shipped with its exit not playing
at all for an unrelated reason, and nothing noticed — see
[04-bugs-fixed.md](04-bugs-fixed.md).

## axe

Runs over **every preview**, at rest and with each layer open, plus contrast in
dark mode. It audited one preview per family until the gallery-filling round
widened the glob to `*/previews/*.html.erb`, and the difference is not
cosmetic: a variant only reachable from a second preview was unaudited, and
widening it caught unnamed inputs, an unlabelled one-time-code field and a
`role="list"` containing a link on the way in. A family with one preview is a
family audited once.

Worth remembering: three of the first 13 "failures" were my own spec bugs —
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

## What the vendored references are worth

`vendor/shadcn/` is checked on every run: `parity_spec` reads it, so a drifted
copy fails the suite. **`vendor/radix/`, `vendor/shadcn-react/` and
`vendor/vaul/` are policed by nobody.** No spec reads any of them — each README
says so — and each can go stale the moment upstream ships past the commit in its
`REVISION`. They are citation sources, not fixtures.

`vendor/vaul/` is the odd one: it is a *stylesheet*, and part of it is
reproduced in `shadcn.css` and does run. Nothing checks that the two agree.
`parity_spec` cannot — it compares Tailwind class text, and a rule in a
stylesheet is not a class.

`vendor/shadcn-react/` is the newest and the odd one: `@shadcn/react` is not a
primitive shadcn wraps but one shadcn *publishes*, MIT and dependency-free, in
the same repository `vendor/shadcn/` comes from. It is vendored for the same
reason `vendor/radix/` is — a reimplementation with nothing to check itself
against is guesswork.

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

**And opening it settles shape, not appearance.** The message scroller's buttons
looked wrong beside the live demo's — `rounded-md` with no border against
`rounded-2xl` with one — and nothing was wrong: that page serves the Base UI
registry, whose Button is a different component from `new-york-v4`'s. Which
parts nest where, and which element owns which attribute, transfer from the
demo. How it *looks* does not, because the look belongs to a registry this gem
does not port. Check a class string against `vendor/shadcn/ui/`.

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

That one is covered now, by a route that avoids the driver entirely — see
[CDP](#when-seleniums-pointer-will-not-land-use-cdp) below.

### `be_visible` does not wait; `have_css` does

`expect(element).to be_visible` reads the state once and never retries, so any
example asserting a state some event is about to change is racing it. Two
scroll-button examples did, passed every local run and two full suites, then
failed during a merge verification. `have_css(selector, visible: :visible)` and
`visible: :hidden` wait, and cannot race.

Repeated green runs are not the argument for the fix — the racing version was
green repeatedly too. The argument is structural: a waiting matcher cannot lose
the race, and the other form can.

The same argument reaches **anything read once**, and `rect` is the usual
offender: a tooltip is unhidden by an attribute landing but *moved* a frame
later, when the reposition's `requestAnimationFrame` runs, so a geometry
assertion taken immediately measures the old place. That example passed alone
and failed in the full suite with exactly the figure the mutation produced.
`page.document.synchronize { … raise Capybara::ExpectationNotMet unless … }`
retries the measurement; it is `have_css`'s waiting for a value no matcher
covers. Two details it needs: `Capybara::ExpectationNotMet` is a subclass of
`ElementNotFound`, so `synchronize` rescues it and re-raises the message on
timeout, and elements with no height — `sidebar-gap` is a spacer with a width
and nothing in it — need `visible: :all` or `find` will not return them.

### `visible:` reads `display`, not opacity

`visible: :visible` and `visible: :hidden` ask the driver whether the element is
*displayed*. An overlay mid-fade, or one whose `fade-out-0` has ended and left it
opaque again, is displayed either way — so an assertion written as "the backdrop
is gone" measured nothing, and a mutation that broke exactly that behaviour went
green. Assert the thing the code controls: the `hidden` attribute, which
`[data-slot][hidden]` turns into `display: none`, is what `visible: :hidden`
then reads.

Where a fade is the subject, `getComputedStyle` through `evaluate_script` is the
instrument — the same one named under *What a system spec cannot see*.

### When Selenium's pointer will not land, use CDP

`move_to` and `click_and_hold` both left the select's scroll buttons untouched —
four attempts, the list never moved a pixel — while a `PointerEvent` dispatched
from the page scrolled it at once. That combination says the handler is fine and
the driver is the obstacle, and it is a trap: dispatching the synthetic event
from `execute_script` would have gone green while proving almost nothing.

`page.driver.browser.execute_cdp("Input.dispatchMouseEvent", type: "mouseMoved",
x:, y:, button: "none")` is a real browser input event, so it exercises the same
path a hand does. It also does *not* scroll the target into view first, which is
what made the earlier attempts pass with the feature removed — the driver was
producing the result the example was looking for.

The example fails with `startAutoScroll` neutralised, which the three attempts
before it did not.

And when the gesture has a *speed*, dispatch touch rather than mouse. The
Drawer's release threshold is distance over elapsed time, so before writing any
of it a control ran first: eight CDP moves 20ms apart arrived with eight
distinct positions and eight distinct timestamps, and the same 240px thrown
(1.99 px/ms) came out 6× faster than dragged (0.31 px/ms). That is what said a
velocity threshold was testable here at all.

`Input.dispatchTouchEvent` rather than `Input.dispatchMouseEvent`, though, and
not for realism: a touch pointer is implicitly captured by whatever it started
on, a mouse pointer is not, and vaul — like this port — binds its handlers to
the panel. Driven by mouse, the moves stop arriving the moment the panel slides
out from under the cursor, so half of every drag is lost and the retracting half
cannot be reached at all. The first version of the drawer spec was written with
the mouse and five examples failed for that reason, which reads exactly like a
broken component.

### Done means the suite is green **and** the page has been looked at

Two steps, both required. Neither substitutes for the other.

**Run the suite.** It catches what it catches.

**Then open the page and look at it.** Every instrument here reads the DOM —
axe reads roles, the snapshots compare HTML, the system specs assert attributes,
the parity pair compares class tokens. **Not one of them renders a picture.** A
component can be wrong in every way that matters to a person while every
assertion about it passes.

These three were the first, all with a green suite:

- the searchable select's cursor moved but coloured nothing, because the
  highlight moved to an attribute no rule styled;
- the Sidebar collapsed to nothing rather than to a rail of icons, because the
  preview took the default `collapsible` where the demo it copies uses `:icon`;
- the Rail was rendered as a sibling of the panel rather than inside it, so its
  `absolute` resolved against the page and drew a two-pixel line straight
  through the icons.

Every one was found by a person opening the page, and every one had passed
everything. **It has kept happening in every branch since**, so the count is no
longer worth keeping: the toaster alone was reported three times — the stack that
did not stack, the flicker between two messages, and the stack that shut when one
was dismissed — and each report arrived on a suite that was green, including the
examples written for the previous one.

All three of those were in the component rather than in its preview; the two
preview-side ones from the same period are the slot-versus-block trap
`CLAUDE.md` names. So: look before calling a component done, and if you have not
looked, say so rather than reporting it finished.

### Assert on what a person would see, not on the element the flag lands on

The sidebar's mobile sheet never showed its panel — the container inside carries
its own `hidden … md:flex`, and `md:flex` can only ever switch on *above* the
breakpoint it names. The spec asserted `have_css("[data-slot=sidebar]", visible:
:visible)` and was green for the whole branch, because the flag and the inline
`display` land on the outer element, which turns visible whether or not anything
inside it does.

Nothing in the earlier entries would have caught it. It is not a race, not an
appearance-versus-DOM gap, and not a missing control: the assertion was correct,
waited properly, and discriminated — one element too far out. The design spec
made the same mistake in prose, naming the panel's `hidden … md:block` as *the*
class that hides it.

The question that catches it is the one already in `CLAUDE.md` for comments,
asked of a selector instead: **which element did I name, and is it the one a
person looks at?** A wrapper, a provider and a group root are all things a flag
naturally lands on and none of them are what anybody sees. Reach one level in —
`sidebar-container` and its width, not `sidebar` and its visibility.

### A number in a geometry assertion is a claim about today's CSS

`sidebar_spec.rb` asserted the gap between a collapsed rail and the tooltip
labelling it, against a constant. It went red on the merged tree the day the
tooltip grew an arrow — because `popper.js` folds an arrow's height into the side
offset, which is Radix's own rule, and the gap legitimately changed. The
assertion was about the tooltip *staying on its anchor as the anchor shrinks*,
and the number was never what it was checking.

It now measures against the arrow's own height. Two things that buys: the
example keeps testing what it is named after, and it fails the day the arrow
stops being drawn instead of silently widening.

The rule: **measure against the thing, not against what the thing measured
last time.** A hardcoded pixel figure in an assertion is either the subject —
say so — or a snapshot of unrelated CSS that will go red for the wrong reason.

### Dispatching a key at a chosen element proves the handler, never the focus

The menubar's panel shipped without `tabindex="-1"`, so `focus()` on it was
silently a no-op and an opened menu held no focus at all: no arrow keys, no
typeahead, no Escape. Ten system examples were green over it. Each one had
picked its own element and dispatched a `KeyboardEvent` there —
`document.querySelector(panel).dispatchEvent(…)` — which is a direct call to
the handler with the focus question written out of the test.

The pull toward doing that is real and looks like diligence: `send_keys` on the
panel fails with `ElementNotInteractable` while the bug is present, and
dispatching is the obvious way past a failing step. That failure *was* the
finding.

So: at least one example per interactive family has to type the way a person
does — **`send_keys` on the element the component focused, never on one the
spec looked up.** Dispatching stays useful for the cases it is honest about
(an event a driver cannot produce, a handler being checked in isolation), and
its comment should say which. What it cannot stand in for is the question of
whether the keyboard arrives at all, and that question has no separate spec:
it is only ever answered as a side effect of typing.

The same run also produced the opposite lesson. A `handOver()` was written on
the dropdown so a menu handing the bar to a sibling would not take the focus
back — reasoned from Radix, where the rule is real
(`vendor/radix/ui/menubar.tsx:324-330`). No mutation could distinguish it,
including one that read `activeElement` *after* the exit animation rather than
before. Our close returns focus synchronously, before the new panel opens, so
there was nothing to prevent. It was deleted. A citation establishes that
upstream needed something; only a failing spec establishes that we do.

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
- **The Drawer's `shouldDrag`, where it decides between the drag and a scroll.**
  Both the climb up to the first scrolled ancestor and the direction
  short-circuit above it are unreachable from a spec here: measured, Chrome
  cancels a pointer stream that starts inside a scroll container — whichever way
  it then travels — and scrolls the container itself, so the gesture ends before
  our code is asked. `spec/system/drawer_spec.rb` asserts the outcome a person
  gets and says in the example itself that the platform is what produces it.
  The branches stay, because they are vaul's and they answer wherever the
  platform does not step in first, which is every device this gem ships to and
  none it can be tested on here. See [features/drawer.md](../features/drawer.md).

### A browser that already does it will pass your spec for you

The message scroller holds the reader's position when older messages load
above. Its first example asserted exactly that, and passed with the entire
feature deleted — Chrome anchors scroll natively and was doing the work.

This is not the same failure as *Run a control, every time*. There the spec was
measured against a baseline and the baseline was missing; here the baseline was
the platform, quietly supplying the behaviour under test. The controller is even
written to be a no-op where the browser got there first, which is correct and is
precisely what made the example vacuous.

The fix is to remove the platform's help rather than to assert harder:
`overflow-anchor: none` on the content is what turns "does a scroller hold its
position?" into "does *this code* hold it?". Reach for the same move whenever
the behaviour under test has a native equivalent — smooth scrolling, scroll
anchoring, lazy loading, form validation, dialog focus. The question to ask is
not *does it work* but **what would still be true if I deleted my code?**

### The harness zeroes animation durations, and one utility needs them

`Capybara.disable_animation` injects `* { animation-duration: 0s !important }`
into every page, and the driver runs with `--force-prefers-reduced-motion`.
Elsewhere that is right — an animation is only something to wait out — but it is
not neutral for anything whose *value* is interpolated rather than merely
tweened over time.

`scroll-fade-x`, ported for the attachment, fades a scroller's edges from a
scroll timeline: two 1ms animations exist only to interpolate two mask offsets
against `scroll(self inline)`. Forced to `0s` they land on their end value, so
the leading edge is masked at rest and a screenshot taken through this suite
shows a fade that a real browser does not. Measured both ways —
`--scroll-fade-s` is the full fade size under the harness and `0` at
`scrollLeft: 0` once `force_animations` hands the duration back.

The general form: **a screenshot from this suite is not evidence about anything
animated**, and `force_animations` is the instrument that makes it one. That
helper was written for exit animations; this is the second thing it is for.
