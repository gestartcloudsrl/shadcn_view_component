# Exit animations — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every `data-[state=closed]:animate-out` class in the port actually
play, by deferring the DOM teardown of a closing layer until its animation has
finished.

**Architecture:** One shared `ExitQueue` in `app/javascript/shadcn/animation.js`
holds teardowns that are waiting on `element.getAnimations()`. Closing splits in
two: everything about *interaction* (dismiss layer, aria, focus, scroll lock)
stays immediate, everything about *presence in the DOM* (`hidden`, unwrapping,
`hidePopover()`) goes through the queue. When no animation is running the queue
runs the teardown synchronously, so behaviour is unchanged wherever the
animation does not exist.

**Tech Stack:** Plain ES modules (no build step, no npm), Stimulus 3, Tailwind 4
`@utility`, RSpec + Capybara + headless Chrome.

---

## The design

### The bug

Closing sets `hidden` in the same tick that sets `data-state="closed"`, and
`[data-slot][hidden] { display: none !important }` removes the element before a
single frame of the exit keyframes can paint. The markup matches shadcn; the
behaviour does not.

Three closing paths carry it, not the two [todo](../todo.md) records. The third
turned up while reading the code.

| path | components |
|---|---|
| `floating.js#hide` | popover, dropdown menu (and submenu), select, tooltip |
| `dialog_controller#render` | dialog, alert dialog, sheet, and the dialog overlay |
| `accordion_controller#render` | accordion — `animate-accordion-up` is inert for the same reason |

Collapsible runs the same machinery but upstream gives its content no animation
classes, so it has nothing to repair and is left alone.

### Why `getAnimations()` and not `animationend`

`animationend` bubbles from descendants, so it needs filtering by both `target`
and `animationName`; worse, it never fires at all when no animation applies,
which forces a timeout — and that timeout then becomes the *normal* path in a
host that has not loaded this gem's CSS. A library cannot ship a delay that only
exists because its own stylesheet is missing.

`getAnimations()` asks the browser what is actually running on that element. An
empty list is unambiguous and needs no fallback, and every degenerate case
collapses to today's behaviour on its own: CSS not built, host overriding the
classes away, reduced motion.

That is why `ExitQueue.defer` runs its teardown **synchronously** when the list
is empty, rather than through a resolved promise. It is what keeps closing
instant in a host that never loaded this stylesheet, and what keeps the existing
system specs from turning into timing tests.

### What waits and what does not

Anything that governs *interaction* happens immediately; anything that governs
*presence in the DOM* waits.

**Immediate.** `data-state="closed"` on content and trigger — first, since it is
what starts the animation — plus `removeLayer` from the dismiss stack (Escape
must not reach a layer that is on its way out), `aria-expanded="false"`, focus
release and restore, scroll unlock, and the `close` event.

**Deferred until settled.** `hidden = true`, moving the content back from the
popper wrapper to its placeholder, `hidePopover()`, and removing the wrapper.

**Forced and synchronous.** `disconnect()`, where Turbo may be detaching the
element and a continuation would be operating on a subtree that has left the
document. Reopening mid-exit instead *cancels* the pending teardown and reuses
the wrapper that is still in place.

The bookkeeping lives in one keyed structure rather than at three call sites:
the dialog needs it per element, the accordion per panel.

### Why the marker, not the state

`[data-slot][data-exiting]` rather than `[data-slot][data-state="closed"]`.
`data-state="closed"` is also written to **triggers** — `floating.js` sets it on
the trigger, `accordion_controller` on the trigger and its header — and all of
those carry a `data-slot`. Keying on state would make every closed select,
dropdown and accordion permanently unclickable.

### Two declared departures from upstream

1. **Reduced motion.** `tw-animate-css` ships no handling for it. Added here as
   a library-appropriate default, nested inside the `@utility` bodies.
2. **A layer stops following its anchor while it fades.** `floating.js#hide`
   drops the scroll and resize listeners at once. Radix keeps positioning until
   unmount; matching it needs a second flag beside `this.open`, which
   `reposition()` returns early on. 150ms of drift is not worth a second piece
   of open/closed state to keep in sync.

### What the tests will not prove

That the animations look right. They assert an animation of the expected name
was scheduled and that the element eventually leaves; they say nothing about
duration, easing, or whether an exit reads as the reverse of its entrance. That
needs eyes on the gallery.

---

## Global Constraints

- **No npm, no runtime JS dependency.** Plain ES modules under
  `app/javascript/shadcn`. `config/importmap.rb` uses `pin_all_from`, so a new
  file needs no registration.
- **JS house style:** no semicolons, double quotes, two-space indent, spaces
  inside array literals (`[ this.trigger ]`). Match the surrounding files.
- **Never split a Tailwind class string across a `\` line continuation.**
  Tailwind scans source text; half a token generates no CSS. `parity_spec`
  catches it.
- **Generated files are never hand-edited:** `lib/shadcn_view_component/themes.rb`,
  `app/assets/stylesheets/shadcn-themes.css`, and the `shadcn-tokens` block
  inside `shadcn.css`. Nothing in this plan touches them.
- **Attribute precedence is `data-slot` < component defaults < caller.** Nothing
  in this plan changes rendered attributes, so no snapshot regeneration.
- **Spec conventions:** the `rspec-conventions` skill. Relevant here: conditions
  go in `context` (starting `when`/`with`/`without`), no "should", multiple
  expectations per example are fine in system specs, and Capybara negatives use
  `have_no_css` rather than `to_not have_css`.
- **After every task:** `bundle exec rspec <the spec you touched>` then
  `bin/rubocop`.
- **Rebuild CSS before running system specs** if `shadcn.css` changed:
  `cd test/dummy && bin/rails tailwindcss:build`. Without it the gallery renders
  unstyled rather than erroring, and animation assertions fail for the wrong
  reason.

## File Structure

| file | responsibility |
|---|---|
| `app/javascript/shadcn/animation.js` | **new.** `ExitQueue` — the only place that knows how to wait for an animation |
| `app/javascript/shadcn/floating.js` | popover/dropdown/select/tooltip: split `show`/`hide` into mount/dismount around the queue |
| `app/javascript/shadcn/controllers/dialog_controller.js` | dialog/alert-dialog/sheet: `render()` defers hiding, per element |
| `app/javascript/shadcn/controllers/accordion_controller.js` | accordion: defer `hidden`, keep the height variable until settled |
| `app/assets/stylesheets/shadcn.css` | `[data-slot][data-exiting]` non-interactive; reduced-motion inside the `@utility` blocks |
| `spec/support/system.rb` | two helpers that make an animation observable in a suite configured to suppress them |
| `spec/system/exit_animation_spec.rb` | **new.** one example per closing path, plus the two interruption cases |

---

### Task 1: A harness that can see an animation at all

The suite is configured to suppress animations, in two independent ways, and
both are right for every other spec. This task makes them observable in one file
without touching the driver, and proves the harness against the **entry**
animation — which already works today, so a green result here means the harness
is sound before any product code moves.

**Files:**
- Modify: `spec/support/system.rb` — add to `module SystemHelpers`, after `state_of`
- Create: `spec/system/exit_animation_spec.rb`

**Interfaces:**
- Produces: `force_animations(selector, duration: "400ms")` and
  `animations_on(selector) -> Array<String>`, used by every later task's specs.

- [ ] **Step 1: Add the two helpers**

In `spec/support/system.rb`, inside `module SystemHelpers`, after the `state_of`
method:

```ruby
  # The driver runs with `--force-prefers-reduced-motion`, and
  # `Capybara.disable_animation` injects `* { animation-duration: 0s !important }`
  # into every page it serves. Both are right for the rest of the suite —
  # elsewhere an animation is only something to wait out — and both make an exit
  # animation impossible to observe.
  #
  # Rather than run this file under a second driver, give the elements under test
  # a duration that outlives an assertion. A class selector with `!important`
  # beats Capybara's rule, which is `!important` at specificity zero. Only the
  # duration is forced: `animation-name` still comes from the component's own
  # `data-[state=closed]:animate-out`, so what the assertions read is the shipped
  # class and not the harness.
  def force_animations(selector, duration: "400ms")
    page.execute_script(<<~JS)
      const style = document.createElement("style")
      style.textContent = "#{selector} { animation-duration: #{duration} !important; }"
      document.head.appendChild(style)
    JS
  end

  # The names of the CSS animations the browser has scheduled on an element.
  # `animate-in` sets `animation-name: enter`, `animate-out` sets `exit`.
  #
  # This is what makes an animation spec deterministic: it reads what the browser
  # decided to run, rather than trying to catch a frame while it runs.
  def animations_on(selector)
    page.evaluate_script(
      "document.querySelector('#{selector}').getAnimations().map((a) => a.animationName)"
    )
  end
```

- [ ] **Step 2: Write the harness spec**

Create `spec/system/exit_animation_spec.rb`:

```ruby
# frozen_string_literal: true

require "spec_helper"

# Every `data-[state=closed]:animate-out` class in the port used to be inert:
# closing set `hidden` in the same tick that set `data-state="closed"`, and
# `[data-slot][hidden] { display: none !important }` removed the element before a
# frame could paint. These examples are what stops that coming back.
#
# They assert on what the browser *scheduled*, never on what is on screen at a
# given moment, so none of them races.
RSpec.describe "Exit animations", :js do
  describe "the harness" do
    let(:content) { "[data-slot=dialog-content]" }

    before do
      visit_preview(:dialog)
      wait_for_stimulus
      force_animations(content)
    end

    # Entry animations have always worked. If this example fails, the harness is
    # broken rather than the product — check that the Tailwind bundle is built.
    it "can observe an animation the suite otherwise suppresses" do
      click_button "Edit profile"

      expect(animations_on(content)).to include("enter")
    end
  end
end
```

- [ ] **Step 3: Run it**

```sh
bundle exec rspec spec/system/exit_animation_spec.rb
```

Expected: **PASS**. If it fails with an empty array, run
`cd test/dummy && bin/rails tailwindcss:build` and try again — the animation
classes live in the compiled bundle.

- [ ] **Step 4: Rubocop**

```sh
bin/rubocop spec/support/system.rb spec/system/exit_animation_spec.rb
```

- [ ] **Step 5: Commit**

```sh
git add spec/support/system.rb spec/system/exit_animation_spec.rb
git commit -m "Make animations observable in one system spec

The driver forces reduced motion and Capybara injects a zero-duration
rule into every page, so an exit animation cannot be seen. Force a
duration on the elements under test instead of adding a second driver;
only the duration is overridden, so the animation name still comes from
the component's own class."
```

---

### Task 2: `ExitQueue`, and the floating layers that use it

**Files:**
- Create: `app/javascript/shadcn/animation.js`
- Modify: `app/javascript/shadcn/floating.js` — `show`, `hide`, `destroy`; add `mount`, `dismount`
- Modify: `app/assets/stylesheets/shadcn.css` — one rule in the existing `@layer base`
- Modify: `spec/system/exit_animation_spec.rb`

**Interfaces:**
- Produces: `class ExitQueue` with `defer(element, teardown)`, `flush(element)`,
  `cancel(element)`, `has(element) -> Boolean`, `flushAll()`. Tasks 3 and 4
  consume it unchanged.

- [ ] **Step 1: Write the failing spec**

Add to `spec/system/exit_animation_spec.rb`, inside the top-level `describe`,
after the `describe "the harness"` block:

```ruby
  describe "a floating layer" do
    let(:content) { "[data-slot=popover-content]" }

    def trigger = find("[data-slot=popover-trigger]")

    before do
      visit_preview(:popover)
      wait_for_stimulus
      force_animations(content)
      trigger.click
      expect(page).to have_css(content)
      press(:escape)
    end

    it "schedules the exit animation the component ships" do
      expect(animations_on(content)).to include("exit")
    end

    it "keeps the content in the document until the animation finishes" do
      expect(page).to have_css(content)
      expect(page).to have_no_css(content) # Capybara waits out the 400ms
    end

    it "stops answering the dismiss layer as soon as it starts closing" do
      expect(state_of(content)).to eq("closed")
      expect(trigger["aria-expanded"]).to eq("false")
    end
  end
```

- [ ] **Step 2: Run it and watch it fail**

```sh
bundle exec rspec spec/system/exit_animation_spec.rb -e "a floating layer"
```

Expected: **FAIL**. `schedules the exit animation` gets `[]` and
`keeps the content in the document` fails its first expectation — today the
element is `hidden` before the assertion can run.

- [ ] **Step 3: Create the queue**

Create `app/javascript/shadcn/animation.js`:

```js
// Closing a layer has two halves that used to happen in one tick, which is why
// no `data-[state=closed]:animate-out` class in this library ever played.
//
// `data-state="closed"` and everything about *interaction* — the dismiss layer,
// aria, focus, the scroll lock — has to be immediate: a layer on its way out
// must not answer Escape. Taking the element out of the DOM has to wait, or the
// exit keyframes never get a frame.
//
// `getAnimations()` rather than an `animationend` listener. The event bubbles
// from descendants, so it would need filtering by both target and name; worse,
// it never fires when no animation applies, which forces a timeout — and that
// timeout then becomes the *normal* path in a host that has not loaded this
// gem's stylesheet. An empty animation list is unambiguous and needs no
// fallback.

// Holds teardowns that are waiting on an element's exit animation, one per
// element.
export class ExitQueue {
  constructor() {
    this.pending = new Map()
  }

  // Runs `teardown` once the animations already running on `element` have
  // finished — or immediately and synchronously when there are none. That last
  // part is the point: a host that never loaded this stylesheet, a host that
  // overrode the classes away, a user who asked for reduced motion, all keep
  // exactly today's behaviour.
  //
  // A second call for an element already waiting is ignored, so a `turbo:morph`
  // re-render in the middle of an exit cannot queue the same teardown twice.
  defer(element, teardown) {
    if (this.pending.has(element)) return

    const running = element.getAnimations().filter((a) => a.playState === "running")

    if (!running.length) {
      teardown()
      return
    }

    // Read by `[data-slot][data-exiting]`, which stops the element intercepting
    // clicks while it fades. Radix does the same; without it a dialog overlay
    // swallows clicks for the 200ms it takes to disappear. The attribute exists
    // only for the length of the animation — it is never rendered markup.
    element.dataset.exiting = ""
    this.pending.set(element, teardown)

    // Reopening mid-exit cancels the animation, which rejects `finished`. Either
    // way the waiting is over; whether the teardown still applies is decided by
    // whoever calls `cancel`.
    Promise.all(running.map((a) => a.finished))
      .catch(() => {})
      .then(() => this.flush(element))
  }

  // Runs a pending teardown now. Called when the animation ends, and directly
  // from `disconnect()`, where waiting is not an option: Turbo may be detaching
  // the element, and a continuation would then be operating on a subtree that
  // has left the document.
  flush(element) {
    const teardown = this.pending.get(element)
    if (!teardown) return

    this.pending.delete(element)
    delete element.dataset.exiting
    teardown()
  }

  // Drops a pending teardown without running it — the element is opening again,
  // so there is nothing left to take out of the DOM.
  cancel(element) {
    if (!this.pending.delete(element)) return

    delete element.dataset.exiting
  }

  has(element) {
    return this.pending.has(element)
  }

  flushAll() {
    for (const element of [ ...this.pending.keys() ]) this.flush(element)
  }
}
```

- [ ] **Step 4: Add the CSS rule**

In `app/assets/stylesheets/shadcn.css`, inside the existing `@layer base`,
immediately after the `[data-slot][hidden]` rule:

```css
  /* Content on its way out stays painted but stops intercepting clicks, as
     Radix does. The marker is written by `ExitQueue` and lives only for the
     length of the animation.

     Keyed on the marker rather than on `[data-state="closed"]`, which is also
     written to *triggers* — `floating.js` sets it on the trigger,
     `accordion_controller` on the trigger and its header — and every one of
     those carries a `data-slot`. Keying on state would make each closed select,
     dropdown and accordion permanently unclickable. */
  [data-slot][data-exiting] {
    pointer-events: none;
  }
```

- [ ] **Step 5: Rework `floating.js`**

Add the import at the top, next to the existing ones:

```js
import { ExitQueue } from "shadcn/animation"
```

In `constructor`, after `this.frame = null`:

```js
    this.exits = new ExitQueue()
```

Replace `show()`, `hide()` and `destroy()`, and add `mount()` and `dismount()`:

```js
  show() {
    if (this.open) return
    this.open = true

    // Reopened before the exit finished — the wrapper, the placeholder and the
    // content are all still in place, so only the interaction state has to come
    // back. Rebuilding them would strand the old placeholder and leave a second
    // wrapper in the DOM.
    if (this.exits.has(this.content)) {
      this.exits.cancel(this.content)
    } else {
      this.mount()
    }

    this.content.hidden = false
    this.content.dataset.state = "open"
    if (this.trigger) this.trigger.dataset.state = "open"

    this.applyPosition()

    window.addEventListener("scroll", this.reposition, true)
    window.addEventListener("resize", this.reposition)

    this.layer = pushLayer({
      element: this.content,
      anchors: [ this.trigger ],
      onDismiss: (event) => (this.onDismiss ? this.onDismiss(event) : this.hide())
    })

    this.onOpen()
  }

  // Leave a marker where the content was, so closing puts it back exactly
  // there. Appending to `home` instead would quietly reorder the markup —
  // after one open/close a Select's content ends up after the hidden input.
  mount() {
    this.placeholder = document.createComment("shadcn-floating-content")
    this.content.replaceWith(this.placeholder)

    this.wrapper = createWrapper()
    this.placeholder.parentNode.insertBefore(this.wrapper, this.placeholder)
    this.wrapper.appendChild(this.content)

    // Above every stacking context, without leaving the DOM.
    topLayer.enable(this.wrapper)
    topLayer.show(this.wrapper)
  }

  hide() {
    if (!this.open) return
    this.open = false

    // Everything here is interaction state, and all of it is immediate: a layer
    // that is fading out must not answer Escape or an outside click.
    window.removeEventListener("scroll", this.reposition, true)
    window.removeEventListener("resize", this.reposition)

    if (this.frame) cancelAnimationFrame(this.frame)
    this.frame = null

    if (this.layer) removeLayer(this.layer)
    this.layer = null

    // This is what starts the exit animation, so it has to be set before the
    // queue looks for one.
    this.content.dataset.state = "closed"
    if (this.trigger) this.trigger.dataset.state = "closed"

    this.exits.defer(this.content, () => this.dismount())

    this.onClose()
  }

  dismount() {
    this.content.hidden = true

    if (this.placeholder?.parentNode) {
      this.placeholder.replaceWith(this.content)
    } else {
      this.home.appendChild(this.content)
    }
    this.placeholder = null

    if (this.wrapper) {
      topLayer.hide(this.wrapper)
      this.wrapper.remove()
    }
    this.wrapper = null
  }

  destroy() {
    this.hide()
    // Turbo may be detaching the element; there is nothing to animate for and
    // nowhere to put the content back afterwards.
    this.exits.flushAll()
  }
```

`toggle()`, `reposition()` and `applyPosition()` are unchanged. Delete the old
comment block above the placeholder creation from `show()` — it moves to
`mount()` with the code it describes.

One deliberate loss, recorded in the design above: the scroll and resize listeners
go at once, so a layer no longer follows its anchor while it fades. Keeping it
would need a second flag beside `this.open`, because `reposition()` returns
early on it.

- [ ] **Step 6: Rebuild CSS and run the spec**

```sh
cd test/dummy && bin/rails tailwindcss:build && cd ../..
bundle exec rspec spec/system/exit_animation_spec.rb
```

Expected: **PASS**, all four examples.

- [ ] **Step 7: Run every spec that drives a floating layer**

```sh
bundle exec rspec spec/system/overlays_spec.rb spec/system/select_spec.rb \
  spec/system/dropdown_menu_spec.rb spec/system/stacking_context_spec.rb \
  spec/system/turbo_spec.rb
```

(Popover and Tooltip live in `overlays_spec.rb`; there is no `popover_spec.rb`.)

Expected: **PASS**. These run with animations suppressed, so `defer` takes its
synchronous branch and nothing about their timing changes. A failure here means
the mount/dismount split lost something, not that the specs need loosening.

- [ ] **Step 8: Rubocop and commit**

```sh
bin/rubocop
git add app/javascript/shadcn/animation.js app/javascript/shadcn/floating.js \
        app/assets/stylesheets/shadcn.css spec/system/exit_animation_spec.rb
git commit -m "Let floating layers finish their exit animation

Closing set \`hidden\` in the same tick as \`data-state=closed\`, so the
exit keyframes never got a frame. Split the DOM teardown out of hide()
and put it behind a queue that waits on getAnimations().

An empty animation list runs the teardown synchronously, which is what
keeps closing instant in a host that never loaded this stylesheet."
```

---

### Task 3: The dialog family

Dialog, AlertDialog and Sheet share one controller and one bug. The overlay and
the content are separate elements with different durations, so they settle
independently.

**Files:**
- Modify: `app/javascript/shadcn/controllers/dialog_controller.js`
- Modify: `spec/system/exit_animation_spec.rb`

**Interfaces:**
- Consumes: `ExitQueue` from Task 2 — `defer`, `cancel`, `flushAll`.

- [ ] **Step 1: Write the failing spec**

Add to `spec/system/exit_animation_spec.rb`, after the `describe "a floating
layer"` block:

```ruby
  describe "the dialog family" do
    let(:content) { "[data-slot=dialog-content]" }
    let(:overlay) { "[data-slot=dialog-overlay]" }

    before do
      visit_preview(:dialog)
      wait_for_stimulus
      force_animations(content)
      force_animations(overlay, duration: "200ms")
      click_button "Edit profile"
      expect(page).to have_css(content)
      press(:escape)
    end

    it "schedules an exit animation on the content" do
      expect(animations_on(content)).to include("exit")
    end

    # Sheet content is `duration-300` against the overlay's `duration-200`. One
    # shared wait would hold whichever finishes first on screen past its own
    # animation, so each element waits on its own.
    it "lets the overlay finish before the content" do
      expect(page).to have_no_css(overlay)
      expect(page).to have_css(content)
      expect(page).to have_no_css(content)
    end

    it "gives focus back and unlocks scrolling without waiting" do
      expect(page.evaluate_script("document.activeElement.dataset.slot")).to eq("dialog-trigger")
      expect(page.evaluate_script("document.body.style.overflow")).to eq("")
    end

    it "does not intercept clicks while it fades" do
      expect(page.evaluate_script("getComputedStyle(document.querySelector('#{overlay}')).pointerEvents"))
        .to eq("none")
    end
  end
```

- [ ] **Step 2: Run it and watch it fail**

```sh
bundle exec rspec spec/system/exit_animation_spec.rb -e "the dialog family"
```

Expected: **FAIL** on the first, second and fourth examples. The third already
passes — focus and scroll are immediate today and must stay that way.

- [ ] **Step 3: Rework the controller**

Add the import next to the others:

```js
import { ExitQueue } from "shadcn/animation"
```

In `connect()`, after `this.layer = null`, add:

```js
    this.exits = new ExitQueue()
```

and delete these two lines from `connect()` — `render()` now owns them, and the
server already renders both elements `hidden`:

```js
    if (this.hasContentTarget) this.contentTarget.hidden = !this.openValue
    if (this.hasOverlayTarget) this.overlayTarget.hidden = !this.openValue
```

Replace `disconnect()`:

```js
  disconnect() {
    this.teardown()
    // Turbo may be detaching the element; a continuation would then be
    // operating on a subtree that has left the document.
    this.exits.flushAll()
  }
```

Replace `render()` and `promote()` with:

```js
  render() {
    const state = this.openValue ? "open" : "closed"

    if (this.hasContentTarget) this.contentTarget.id ||= uniqueId("shadcn-dialog")

    for (const element of this.layers) {
      element.dataset.state = state

      // A modal inside a `sticky z-40` header or an `isolate` card would
      // otherwise be buried by whatever sits above that stacking context.
      topLayer.enable(element)

      if (this.openValue) {
        this.exits.cancel(element)
        element.hidden = false
        topLayer.show(element)
      } else if (!element.hidden) {
        // Each element waits on its own animations: sheet content is
        // `duration-300` against the overlay's `duration-200`.
        this.exits.defer(element, () => {
          element.hidden = true
          topLayer.hide(element)
        })
      }
    }

    if (!this.hasTriggerTarget) return

    this.triggerTarget.dataset.state = state
    this.triggerTarget.setAttribute("aria-expanded", String(this.openValue))
    this.triggerTarget.setAttribute("aria-haspopup", "dialog")
    if (this.hasContentTarget) {
      this.triggerTarget.setAttribute("aria-controls", this.contentTarget.id)
    }
  }

  // Overlay first, content second: the top layer stacks in the order things are
  // shown, so the dialog ends up above its own backdrop.
  get layers() {
    return [
      this.hasOverlayTarget && this.overlayTarget,
      this.hasContentTarget && this.contentTarget
    ].filter(Boolean)
  }
```

`show()`, `hide()` and `teardown()` are unchanged: the focus trap, the scroll
lock and the dismiss layer were already immediate and stay that way.

- [ ] **Step 4: Run the spec**

```sh
bundle exec rspec spec/system/exit_animation_spec.rb
```

Expected: **PASS**, all eight examples.

- [ ] **Step 5: Run everything that drives a dialog**

```sh
bundle exec rspec spec/system/dialog_spec.rb spec/system/overlays_spec.rb \
  spec/system/accessibility_spec.rb spec/system/turbo_spec.rb
```

Expected: **PASS**. `dialog_spec` covers reopening, the close button inside the
content, and the alert dialog's refusal to dismiss — all of which run through
the rewritten `render()`.

- [ ] **Step 6: Rubocop and commit**

```sh
bin/rubocop
git add app/javascript/shadcn/controllers/dialog_controller.js \
        spec/system/exit_animation_spec.rb
git commit -m "Let the dialog family finish its exit animation

Overlay and content settle independently: sheet content is duration-300
against the overlay's duration-200, and a shared wait would hold one of
them on screen past its own animation.

connect() no longer sets \`hidden\` by hand — the server renders both
elements hidden already, and render() is now the only writer."
```

---

### Task 4: The accordion

Not in the todo's account of the bug. `animate-accordion-up` is inert for the
same reason, and the height variable it interpolates towards has to outlive it.

**Files:**
- Modify: `app/javascript/shadcn/controllers/accordion_controller.js`
- Modify: `spec/system/exit_animation_spec.rb`

**Interfaces:**
- Consumes: `ExitQueue` from Task 2 — `defer`, `cancel`, `flushAll`.

- [ ] **Step 1: Write the failing spec**

Add to `spec/system/exit_animation_spec.rb`, after the `describe "the dialog
family"` block:

```ruby
  describe "the accordion" do
    # The preview is `collapsible: true` with `item-1` already open, so the
    # animated transition is its trigger being clicked once.
    let(:content) { "[data-value=item-1] [data-slot=accordion-content]" }

    before do
      visit_preview(:accordion)
      wait_for_stimulus
      force_animations(content)
    end

    context "when a panel is collapsed" do
      before do
        expect(page).to have_css(content)
        click_button "Is it accessible?"
      end

      it "schedules the collapse animation" do
        expect(animations_on(content)).to include("accordion-up")
      end

      # `--radix-accordion-content-height` is what the keyframes interpolate
      # towards. Clearing it early leaves the animation collapsing to a height
      # that no longer exists.
      it "keeps the height it is collapsing towards until it lands" do
        height = page.evaluate_script(
          "document.querySelector('#{content}')" \
          ".style.getPropertyValue('--radix-accordion-content-height')"
        )

        expect(height).not_to be_empty
        expect(page).to have_no_css(content)
      end
    end
  end
```

- [ ] **Step 2: Run it and watch it fail**

```sh
bundle exec rspec spec/system/exit_animation_spec.rb -e "the accordion"
```

Expected: **FAIL** — `animations_on` returns `[]`, because the panel is `hidden`
before the assertion runs.

- [ ] **Step 3: Rework the controller**

Add the import next to the others:

```js
import { ExitQueue } from "shadcn/animation"
```

Replace `connect()` and add a `disconnect()`:

```js
  connect() {
    this.exits = new ExitQueue()
    this.render()
  }

  disconnect() {
    // Turbo may be detaching the element; a continuation would then be
    // operating on a subtree that has left the document.
    this.exits.flushAll()
  }
```

In `render()`, replace the closing `if (isOpen) { … } else { … }` block with:

```js
      if (isOpen) {
        this.exits.cancel(content)
        content.hidden = false
        content.style.setProperty(
          "--radix-accordion-content-height",
          `${content.scrollHeight}px`
        )
      } else if (!content.hidden) {
        // The height stays published until the collapse lands — it is what
        // `animate-accordion-up` interpolates towards.
        this.exits.defer(content, () => {
          content.hidden = true
          content.style.removeProperty("--radix-accordion-content-height")
        })
      }
```

- [ ] **Step 4: Run the spec**

```sh
bundle exec rspec spec/system/exit_animation_spec.rb
```

Expected: **PASS**, all ten examples.

- [ ] **Step 5: Run the disclosure specs**

```sh
bundle exec rspec spec/system/disclosure_spec.rb spec/system/accessibility_spec.rb
```

Expected: **PASS**.

- [ ] **Step 6: Rubocop and commit**

```sh
bin/rubocop
git add app/javascript/shadcn/controllers/accordion_controller.js \
        spec/system/exit_animation_spec.rb
git commit -m "Let the accordion finish collapsing

\`animate-accordion-up\` was inert for the same reason every other exit
animation was, and the todo did not record it. The collapsing panel now
keeps --radix-accordion-content-height until it lands, since that is the
height the keyframes interpolate towards."
```

---

### Task 5: Reduced motion

A declared departure from upstream: `tw-animate-css` ships no reduced-motion
handling. It is a library-appropriate default, and it has to live *inside* the
utility definitions — the components apply these through variants, so the
emitted class is literally named `data-[state=closed]:animate-out` and a
top-level `.animate-out { }` rule matches nothing.

**Files:**
- Modify: `app/assets/stylesheets/shadcn.css`

- [ ] **Step 1: Nest the media query in the two animation utilities**

In `app/assets/stylesheets/shadcn.css`, add to the body of `@utility animate-in`
and `@utility animate-out`, as the last declaration in each:

```css
  /* A declared departure from upstream: tw-animate-css ships no reduced-motion
     handling. Nested inside the utility because the components apply it through
     variants — the emitted class is `data-[state=closed]:animate-out`, which a
     top-level `.animate-out` rule would not match. */
  @media (prefers-reduced-motion: reduce) {
    animation-duration: 0.01ms;
  }
```

- [ ] **Step 2: Move the accordion animations from `@theme` to `@utility`**

Delete these two lines from the `@theme inline` block:

```css
  --animate-accordion-down: accordion-down 0.2s ease-out;
  --animate-accordion-up: accordion-up 0.2s ease-out;
```

Add, next to the other `@utility` blocks:

```css
/* Defined as utilities rather than `@theme` entries, which is the only place a
   media query can reach them. The generated class name is unchanged. */
@utility animate-accordion-down {
  animation: accordion-down 0.2s ease-out;

  @media (prefers-reduced-motion: reduce) {
    animation-duration: 0.01ms;
  }
}

@utility animate-accordion-up {
  animation: accordion-up 0.2s ease-out;

  @media (prefers-reduced-motion: reduce) {
    animation-duration: 0.01ms;
  }
}
```

Leave `--animate-caret-blink` in `@theme`, and leave `animate-spin` alone: a
frozen loading indicator communicates worse than the motion it would save.

- [ ] **Step 3: Rebuild and prove the classes still resolve**

```sh
cd test/dummy && bin/rails tailwindcss:build && cd ../..
grep -c "accordion-up" test/dummy/app/assets/builds/*.css
```

Expected: a non-zero count. A zero means the `@utility` rename did not produce
the class and the accordion has silently lost its animation.

- [ ] **Step 4: Run the specs that depend on those classes**

```sh
bundle exec rspec spec/parity_spec.rb spec/snapshot_spec.rb \
  spec/system/exit_animation_spec.rb spec/system/disclosure_spec.rb
```

Expected: **PASS**. `parity_spec` reads the Ruby, not the CSS, so it is unmoved;
it is in the list because a mistyped class name is exactly what it exists to
catch.

- [ ] **Step 5: Commit**

```sh
bin/rubocop
git add app/assets/stylesheets/shadcn.css
git commit -m "Collapse the animations under prefers-reduced-motion

Nested inside the @utility bodies: the components apply these through
variants, so the emitted class is \`data-[state=closed]:animate-out\` and
a top-level .animate-out rule would match nothing. The accordion
animations move from @theme to @utility for the same reason.

animate-spin and caret-blink are left alone — a frozen loading indicator
communicates worse than the motion it saves. A declared departure from
upstream, which ships no reduced-motion handling."
```

---

### Task 6: Tell the docs the truth

Two files state that exit animations never play. After Task 5 they do. This plan
is transient; what outlives it belongs in `02-javascript.md` alongside the other
JavaScript decisions.

**Files:**
- Modify: `.claude/docs/decisions/02-javascript.md`
- Modify: `.claude/docs/todo.md`

- [ ] **Step 1: Correct the paragraph that says they never play**

In `.claude/docs/decisions/02-javascript.md`, replace the paragraph beginning
**"The blocker I had feared did not exist."** with:

```markdown
**The blocker I had feared did not exist.** Exit animations were the reason to
hesitate — and it then turned out they had never played at all, for an unrelated
reason. See below.
```

- [ ] **Step 2: Add the decision itself**

Add to `.claude/docs/decisions/02-javascript.md`, as a new section after
**Layers are promoted with the Popover API instead**:

```markdown
## Closing waits for the animation; everything else does not

Closing used to set `hidden` in the same tick as `data-state="closed"`, and
`[data-slot][hidden]` removes the element outright, so no exit keyframe ever got
a frame. Three paths had it: `floating.js#hide`, `dialog_controller#render`, and
— the one the todo had missed — `accordion_controller#render`.

`ExitQueue` in `animation.js` now holds the DOM half of a close until
`element.getAnimations()` settles. Interaction is untouched by the wait: the
dismiss layer, aria, focus and the scroll lock all release immediately, because a
layer on its way out must not answer Escape.

**Not `animationend`.** It bubbles from descendants, so it needs filtering by
target and name, and it never fires when no animation applies — which forces a
timeout, and that timeout becomes the normal path in a host that has not loaded
this stylesheet. An empty `getAnimations()` list is unambiguous: the teardown
runs synchronously and behaviour is exactly what it was.

Two things were given up on purpose. A floating layer no longer follows its
anchor while it fades (see [todo](../todo.md)). And `prefers-reduced-motion`
collapses these animations, which upstream does not do — a departure taken
because this is a library, and nested inside the `@utility` bodies because the
components apply them through variants.
```

- [ ] **Step 3: `todo.md`**

Remove the **Exit animations do not play** entry from *Coverage gaps worth
closing* — including its link to this plan. Add to *Smaller things*:

```markdown
- [ ] **A layer stops following its anchor while it fades.** `floating.js#hide`
      drops the scroll and resize listeners immediately, so a layer scrolled
      during its exit animation detaches from the trigger for the length of it.
      Radix keeps positioning until unmount; matching that needs a second flag
      beside `this.open`, which `reposition()` returns early on.
```

- [ ] **Step 4: Full suite, then commit**

```sh
bundle exec rake
bin/rubocop
```

Expected: **PASS**, everything.

```sh
git add .claude/docs
git commit -m "Record that exit animations now play

The JavaScript decisions said they never did. Also records the one thing
given up on purpose: a floating layer no longer follows its anchor while
it fades."
```

---

## Self-review

**Design coverage.** Every section of the design above maps to a task: the
mechanism and the `data-exiting` marker → Task 2; the three closing paths →
Tasks 2, 3, 4; reduced motion → Task 5; what waits and what does not → the
immediate/deferred split in Tasks 2 and 3; the two declared departures → Tasks 5
and 6.

**Why Task 1 exists.** The obvious reading of the design — just call
`getAnimations()` in a system spec — does not work. The suite suppresses
animations twice over: the driver runs with `--force-prefers-reduced-motion`,
and `Capybara.disable_animation` injects `* { animation-duration: 0s !important }`
into every page it serves. Both are right for every other spec. Task 1 forces a
duration on the elements under test instead of adding a second driver, and
proves the harness against an entry animation that already works, before any
product code moves.

**Fixture values, checked against the repo rather than assumed.** The popover
preview opens from `find("[data-slot=popover-trigger]").click`, not a button
label — Popover and Tooltip have no spec file of their own, they live in
`overlays_spec.rb`. The accordion preview is `collapsible: true` with `item-1`
already open at load, so one click on *its own* trigger is the collapse, and the
panel is addressed as `[data-value=item-1] [data-slot=accordion-content]`
because three panels share the slot name. The dialog's `"Edit profile"` comes
from `dialog_spec.rb`.

**Naming consistency.** `ExitQueue`, `defer`, `flush`, `cancel`, `has`,
`flushAll`, `this.exits`, `mount`, `dismount`, `layers`, `force_animations`,
`animations_on` — each used with the same signature everywhere it appears.

**What this plan does not prove.** That the animations look right. The specs
assert an animation of the expected name was scheduled and that the element
eventually leaves. Nothing here covers duration, easing, or whether an exit
reads as the reverse of its entrance — that needs eyes on the gallery.
