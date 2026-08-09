# Sidebar (behaviour) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Sidebar's behaviour — open state, persistence, keyboard shortcut and
the mobile branch — as a Stimulus controller, driven by a hand-written page that
doubles as the contract its 24 ViewComponents will have to satisfy.

**Architecture:** The server renders one tree, upstream's desktop one. Below `md`
the controller gives that same DOM the behaviour of a Sheet — top layer, dismiss,
focus trap, scroll lock — without moving it, reusing the four modules
`dialog_controller.js` already composes. State is `open` (persisted in a cookie,
as upstream does) and `openMobile` (never persisted). No ViewComponents are
written in this branch.

**Tech Stack:** Stimulus, Capybara + headless Chrome, the dummy Rails app.

## Global Constraints

Every decision below is settled in
[the design](../specs/2026-08-08-sidebar-mobile-rendering-design.md); this plan
executes it and does not revisit it.

- **No ViewComponents in this branch.** The markup is hand-written in the dummy
  app. The sixteen leaf parts and the eight structural ones come later.
- **Values copied verbatim from `vendor/shadcn/ui/sidebar.tsx`:** cookie name
  `sidebar_state`, max-age `604800`, widths `16rem` / `18rem` / `3rem`, shortcut
  `b` with meta or ctrl, breakpoint `md` = 768px.
- **`data-collapsible` is written empty while expanded** and only filled when
  collapsed (`sidebar.tsx:212`). Writing it unconditionally applies collapsed
  styling to an open sidebar.
- **The cookie gains `samesite=lax`**, the only divergence in that layer, because
  `theme.js` already writes its own that way.
- **No `localStorage`.** One store, so a deleted cookie resets cleanly.
- **The state method must be named `render()`.** `index.js:66-75` re-runs
  `render()` on every `shadcn--*` controller after `turbo:morph`; that is the
  whole morph story, and a differently-named method silently opts out.
- **Never split a class string across a `\` line continuation** — Tailwind scans
  source text, so half a token generates no CSS.
- Run `bundle exec rake` and `bin/rubocop` before every commit. Both clean. Do
  not infer a suite result from a previous run.
- Verify every behaviour by mutation before trusting its spec. Three specs in the
  previous branch passed with the feature removed.

---

## File Structure

**Created**

| File | Responsibility |
|---|---|
| `app/javascript/shadcn/controllers/sidebar_controller.js` | the whole behaviour |
| `test/dummy/app/controllers/sidebar_controller.rb` | serves the contract page |
| `test/dummy/app/views/sidebar/show.html.erb` | the hand-written markup — the contract |
| `spec/system/sidebar_spec.rb` | drives it |

**Modified**

| File | Change |
|---|---|
| `app/javascript/shadcn/index.js` | import and register under `sidebar` |
| `test/dummy/config/routes.rb` | `get "sidebar"` |
| `.claude/docs/decisions/02-javascript.md`, `.claude/docs/todo.md` | Task 6 |

There is no Rails-side naming collision: `test/dummy/app/controllers/sidebar_controller.rb`
is a Rails controller and `app/javascript/shadcn/controllers/sidebar_controller.js`
is a Stimulus one. They share a name because both are named after the thing they
serve.

---

### Task 1: The contract page

**Files:**
- Create: `test/dummy/app/controllers/sidebar_controller.rb`, `test/dummy/app/views/sidebar/show.html.erb`, `spec/system/sidebar_spec.rb`
- Modify: `test/dummy/config/routes.rb`

**Interfaces:**
- Produces: `/sidebar`, serving an element with
  `data-controller="shadcn--sidebar"` and the `data-slot` structure every later
  task drives. Also the page a human opens to look at it.

The dummy app already has this exact pattern: `turbo_probe_controller.rb` exists
because a full page is something a Lookbook preview cannot give. Follow it.

- [ ] **Step 1: Write the failing spec**

`spec/system/sidebar_spec.rb`:

```ruby
# frozen_string_literal: true

require "spec_helper"

# The Sidebar's behaviour, driven from a hand-written page rather than from
# components: none exist yet, and this markup is the contract the 24 of them
# will have to satisfy. See specs/2026-08-08-sidebar-mobile-rendering-design.md.
RSpec.describe "Sidebar", :js do
  let(:sidebar) { "[data-slot=sidebar]" }
  let(:trigger) { "[data-slot=sidebar-trigger]" }

  before do
    visit "/sidebar"
    wait_for_stimulus
  end

  it "renders expanded, with the attributes its classes read" do
    expect(page).to have_css("#{sidebar}[data-state=expanded]")
    expect(find(sidebar)["data-side"]).to eq("left")
    expect(find(sidebar)["data-variant"]).to eq("sidebar")
  end
end
```

- [ ] **Step 2: Run it and watch it fail**

Run: `bundle exec rspec spec/system/sidebar_spec.rb`
Expected: FAIL — `/sidebar` has no route, so the visit raises before any
assertion.

- [ ] **Step 3: Add the route**

In `test/dummy/config/routes.rb`, beside the turbo-probe pair:

```ruby
  # A full-page layout, which a Lookbook preview cannot give — and the markup
  # contract the Sidebar's components will have to emit.
  get "sidebar" => "sidebar#show", as: :sidebar
```

- [ ] **Step 4: Add the Rails controller**

`test/dummy/app/controllers/sidebar_controller.rb`:

```ruby
# frozen_string_literal: true

# Serves the Sidebar contract page. Hand-written markup, because the components
# do not exist yet and this is what they will have to emit.
class SidebarController < ApplicationController
  def show; end
end
```

- [ ] **Step 5: Write the contract markup**

`test/dummy/app/views/sidebar/show.html.erb`. Every attribute here is one a
future component emits; the classes are upstream's, copied from
`vendor/shadcn/ui/sidebar.tsx` at the lines noted.

```erb
<%# The Sidebar's markup contract, hand-written while its components do not
    exist. Classes are upstream's; the `data-*` attributes are what the
    controller reads and writes.

    `data-collapsible` is deliberately empty: upstream fills it only while
    collapsed (sidebar.tsx:212), and the classes match on
    `group-data-[collapsible=icon]:…`. %>
<div data-slot="sidebar-wrapper"
     class="group/sidebar-wrapper flex min-h-svh w-full"
     style="--sidebar-width: 16rem; --sidebar-width-icon: 3rem;"
     data-controller="shadcn--sidebar"
     data-shadcn--sidebar-open-value="true">

  <div data-slot="sidebar"
       data-shadcn--sidebar-target="sidebar"
       data-state="expanded"
       data-collapsible=""
       data-variant="sidebar"
       data-side="left"
       class="group peer hidden text-sidebar-foreground md:block">
    <div data-slot="sidebar-gap"
         class="relative w-(--sidebar-width) bg-transparent transition-[width] duration-200 ease-linear group-data-[collapsible=offcanvas]:w-0"></div>
    <div data-slot="sidebar-container"
         class="fixed inset-y-0 z-10 hidden h-svh w-(--sidebar-width) transition-[left,right,width] duration-200 ease-linear md:flex left-0 group-data-[collapsible=offcanvas]:left-[calc(var(--sidebar-width)*-1)]">
      <div data-sidebar="sidebar"
           data-slot="sidebar-inner"
           class="bg-sidebar flex h-full w-full flex-col group-data-[variant=floating]:border-sidebar-border group-data-[variant=floating]:rounded-lg group-data-[variant=floating]:border group-data-[variant=floating]:shadow-sm">
        <nav class="flex flex-col gap-1 p-2" data-testid="sidebar-nav">
          <a href="#" class="rounded-md px-2 py-1.5 text-sm hover:bg-sidebar-accent">Dashboard</a>
          <a href="#" class="rounded-md px-2 py-1.5 text-sm hover:bg-sidebar-accent" data-testid="nav-last">Settings</a>
        </nav>
      </div>
    </div>
  </div>

  <main data-slot="sidebar-inset" class="relative flex w-full flex-1 flex-col p-4">
    <button type="button"
            data-slot="sidebar-trigger"
            data-shadcn--sidebar-target="trigger"
            data-action="click->shadcn--sidebar#toggle"
            aria-label="Toggle sidebar"
            class="inline-flex size-7 items-center justify-center rounded-md hover:bg-accent">
      <%= render(Shadcn::Icon::Component.new("panel-left", class: "size-4")) %>
    </button>
    <p class="mt-4 text-sm text-muted-foreground">Page content.</p>
  </main>
</div>
```

**`panel-left` is not one of the bundled icons.** `PATHS` in
`app/components/shadcn/icon/component.rb` holds twelve, and an unknown name
*raises* where `Rails.env.local?` — so this page will not render until it is
added. Add it in the same step, in the hash's existing `%(...)` style, using
lucide's `panel-left`:

```ruby
"panel-left" => %(<rect width="18" height="18" x="3" y="3" rx="2"/><path d="M9 3v18"/>),
```

- [ ] **Step 6: Green, and look at it**

Run: `bundle exec rspec spec/system/sidebar_spec.rb`
Expected: PASS.

Then open `http://localhost:3000/sidebar` (`cd test/dummy && bin/rails s`) and
confirm a sidebar and a page body are visible side by side. Nothing toggles yet —
that is Task 2.

- [ ] **Step 7: Commit**

```sh
bundle exec rake && bin/rubocop
git add app/components/shadcn/icon test/dummy spec/system/sidebar_spec.rb
git commit -m "Serve the Sidebar's contract page"
```

---

### Task 2: Open, collapsed, and the attributes the classes read

**Files:**
- Create: `app/javascript/shadcn/controllers/sidebar_controller.js`
- Modify: `app/javascript/shadcn/index.js`
- Test: `spec/system/sidebar_spec.rb`

**Interfaces:**
- Consumes: the page from Task 1.
- Produces: `shadcn--sidebar` with an `open` value, a `toggle()` action, and
  `render()` — the name `index.js:66-75` calls after a morph.

- [ ] **Step 1: Write the failing spec**

Add to `spec/system/sidebar_spec.rb`:

```ruby
  it "collapses and expands, and fills data-collapsible only while collapsed" do
    expect(find(sidebar)["data-collapsible"]).to eq("")

    find(trigger).click
    expect(page).to have_css("#{sidebar}[data-state=collapsed]")
    expect(find(sidebar)["data-collapsible"]).to eq("offcanvas")

    find(trigger).click
    expect(page).to have_css("#{sidebar}[data-state=expanded]")
    expect(find(sidebar)["data-collapsible"]).to eq("")
  end
```

The markup declares `data-collapsible=""`, so the controller has to read the
*intended* value from somewhere else. It reads `data-sidebar-collapsible` on the
same element — add it to the view in Step 3.

- [ ] **Step 2: Run it and watch it fail**

Run: `bundle exec rspec spec/system/sidebar_spec.rb -e "collapses and expands"`
Expected: FAIL — clicking does nothing, so `data-state` stays `expanded`.

- [ ] **Step 3: Give the markup the value to collapse to**

In `test/dummy/app/views/sidebar/show.html.erb`, on the `data-slot="sidebar"`
element, beside `data-collapsible=""`:

```erb
       data-sidebar-collapsible="offcanvas"
```

A comment above it, because the pair looks redundant and is not:

```erb
    <%# Two attributes, deliberately: `data-collapsible` is the live one the
        classes match on and is empty while expanded, so the intended value has
        to live somewhere the controller can still read. %>
```

- [ ] **Step 4: Write the controller**

`app/javascript/shadcn/controllers/sidebar_controller.js`:

```js
import { Controller } from "@hotwired/stimulus"

// Radix has no Sidebar — shadcn builds it on its own React context
// (vendor/shadcn/ui/sidebar.tsx:56). The state is small: expanded or collapsed
// on desktop, a separate ephemeral flag on mobile, and a cookie so a server
// render can start in the right one.
export default class extends Controller {
  static targets = [ "sidebar", "trigger" ]
  static values = { open: Boolean }

  connect() {
    this.render()
  }

  toggle() {
    this.openValue = !this.openValue
    this.render()
  }

  // Named `render` because `index.js` re-runs exactly that on every
  // `shadcn--*` controller after `turbo:morph`, which is what puts a
  // controller back in agreement with markup the server has just rewritten.
  render() {
    if (!this.hasSidebarTarget) return

    const sidebar = this.sidebarTarget

    sidebar.dataset.state = this.openValue ? "expanded" : "collapsed"
    // Upstream writes this empty while expanded and fills it only when
    // collapsed (sidebar.tsx:212); the classes match
    // `group-data-[collapsible=icon]:…`, so filling it always would style an
    // open sidebar as a closed one.
    sidebar.dataset.collapsible = this.openValue ? "" : (sidebar.dataset.sidebarCollapsible || "offcanvas")
  }
}
```

- [ ] **Step 5: Register it**

In `app/javascript/shadcn/index.js`, in the import block and the `CONTROLLERS`
map, both alphabetical:

```js
import SidebarController from "shadcn/controllers/sidebar_controller"
```

```js
  sidebar: SidebarController,
```

- [ ] **Step 6: Green, then verify by mutation**

Run: `bundle exec rspec spec/system/sidebar_spec.rb`
Expected: PASS.

Then change the `data-collapsible` line to write the value unconditionally:

```js
    sidebar.dataset.collapsible = sidebar.dataset.sidebarCollapsible || "offcanvas"
```

Re-run and confirm the example fails on the first assertion — `""` expected,
`"offcanvas"` got. Restore, and confirm `git diff` shows only the intended
change. That mutation is the whole point of the example: an unconditional write
looks correct and styles an open sidebar as closed.

- [ ] **Step 7: Commit**

```sh
bundle exec rake && bin/rubocop
git add app/javascript/shadcn test/dummy spec/system/sidebar_spec.rb
git commit -m "Collapse and expand the Sidebar"
```

---

### Task 3: The cookie

**Files:**
- Modify: `app/javascript/shadcn/controllers/sidebar_controller.js`
- Test: `spec/system/sidebar_spec.rb`

**Interfaces:**
- Consumes: `toggle()` from Task 2.
- Produces: `sidebar_state` in `document.cookie` after a desktop toggle.

Upstream writes the cookie in `setOpen` and **never reads it**
(`sidebar.tsx:86`); reading is the host's job. This port does the same, so
nothing here parses cookies.

No `try`/`catch`. The design's degradation note says `theme.js` wraps its storage
access "for the same reason" — that wrapping is around `localStorage`, which
throws in private browsing; the `document.cookie` assignment sits *outside* it,
because a blocked cookie assignment is a silent no-op rather than an exception.
Wrapping it would suggest a failure mode that does not exist.

- [ ] **Step 1: Write the failing spec**

```ruby
  it "remembers the collapsed state in a cookie the server can read" do
    find(trigger).click
    expect(page).to have_css("#{sidebar}[data-state=collapsed]")

    expect(page.evaluate_script("document.cookie")).to include("sidebar_state=false")

    find(trigger).click
    expect(page).to have_css("#{sidebar}[data-state=expanded]")

    expect(page.evaluate_script("document.cookie")).to include("sidebar_state=true")
  end
```

- [ ] **Step 2: Run it and watch it fail**

Run: `bundle exec rspec spec/system/sidebar_spec.rb -e "remembers the collapsed state"`
Expected: FAIL — `document.cookie` has no `sidebar_state`.

- [ ] **Step 3: Write it on toggle**

In the controller, a constant beside the class and a call in `toggle()`:

```js
// Upstream's own name and lifetime (vendor/shadcn/ui/sidebar.tsx:28-29).
const COOKIE = "sidebar_state"
const COOKIE_MAX_AGE = 60 * 60 * 24 * 7
```

```js
  toggle() {
    this.openValue = !this.openValue
    this.persist()
    this.render()
  }

  // Written, never read: a Rails layout reads it and passes the result back as
  // the `open` value, exactly as a Next.js layout does with `defaultOpen`
  // (vendor/shadcn/ui/sidebar.tsx:86). `samesite=lax` is this port's one
  // addition — upstream's line has no SameSite, and `theme.js` here already
  // writes its cookie with it, so matching upstream character for character
  // would leave one library disagreeing with itself.
  persist() {
    document.cookie =
      `${COOKIE}=${this.openValue}; path=/; max-age=${COOKIE_MAX_AGE}; samesite=lax`
  }
```

- [ ] **Step 4: Green, then verify by mutation**

Run: `bundle exec rspec spec/system/sidebar_spec.rb`
Expected: PASS.

Remove the `this.persist()` call from `toggle()`, re-run, and confirm the example
fails on the first cookie assertion. Restore.

- [ ] **Step 5: Commit**

```sh
bundle exec rake && bin/rubocop
git add app/javascript/shadcn spec/system/sidebar_spec.rb
git commit -m "Persist the Sidebar's state the way upstream does"
```

---

### Task 4: The keyboard shortcut

**Files:**
- Modify: `app/javascript/shadcn/controllers/sidebar_controller.js`
- Test: `spec/system/sidebar_spec.rb`

**Interfaces:**
- Consumes: `toggle()`.
- Produces: `cmd/ctrl+b` toggling from anywhere on the page.

- [ ] **Step 1: Write the failing spec**

```ruby
  it "toggles from anywhere with the shortcut, and leaves a plain b alone" do
    press([ :meta, "b" ])
    expect(page).to have_css("#{sidebar}[data-state=collapsed]")

    press([ :meta, "b" ])
    expect(page).to have_css("#{sidebar}[data-state=expanded]")

    # A bare "b" is a character someone may be typing.
    press("b")
    expect(page).to have_css("#{sidebar}[data-state=expanded]")
  end
```

`press` is the helper in `spec/support/system.rb:110`; it sends to the browser
rather than to an element, which is what a window-level listener needs.

- [ ] **Step 2: Run it and watch it fail**

Run: `bundle exec rspec spec/system/sidebar_spec.rb -e "toggles from anywhere"`
Expected: FAIL — the state stays `expanded`.

- [ ] **Step 3: Bind and unbind it**

Upstream binds on `window` and removes on unmount (`sidebar.tsx:96-111`). A
Stimulus controller's `disconnect()` is the same moment, and skipping it leaks a
listener on every Turbo navigation.

```js
const SHORTCUT = "b"
```

```js
  connect() {
    this.onKeydown = (event) => {
      if (event.key !== SHORTCUT) return
      if (!event.metaKey && !event.ctrlKey) return

      event.preventDefault()
      this.toggle()
    }

    window.addEventListener("keydown", this.onKeydown)
    this.render()
  }

  disconnect() {
    window.removeEventListener("keydown", this.onKeydown)
  }
```

- [ ] **Step 4: Green, then verify by mutation**

Run: `bundle exec rspec spec/system/sidebar_spec.rb`
Expected: PASS.

Drop the `if (!event.metaKey && !event.ctrlKey) return` guard, re-run, and
confirm the example fails on its last assertion — a bare `b` now toggles.
Restore.

- [ ] **Step 5: Commit**

```sh
bundle exec rake && bin/rubocop
git add app/javascript/shadcn spec/system/sidebar_spec.rb
git commit -m "Toggle the Sidebar with cmd/ctrl+b"
```

---

### Task 5: The mobile branch

**Files:**
- Modify: `app/javascript/shadcn/controllers/sidebar_controller.js`, `test/dummy/app/views/sidebar/show.html.erb`
- Test: `spec/system/sidebar_spec.rb`

**Interfaces:**
- Consumes: everything above.
- Produces: below 768px, the same DOM behaving as a Sheet.

This is the task the design exists for. React renders a different tree here; this
port keeps one and changes its behaviour, because moving content out of the
controller's element unbinds the Stimulus actions inside it — the reason nothing
in this gem is portalled (`decisions/02-javascript.md`).

Four modules already do this work for `dialog_controller.js`, which is also what
Sheet uses. Reuse them rather than reimplementing:

```js
import { pushLayer, removeLayer } from "shadcn/dismiss"
import { trapFocus, focusFirst, lockScroll, unlockScroll } from "shadcn/focus"
import * as topLayer from "shadcn/top_layer"
```

**The `hidden md:block` problem.** Upstream's desktop tree is CSS-hidden below
`md` (`sidebar.tsx:210`) because React never renders it there. Keeping it means
the mobile branch has to make it visible, and the design left *how* to this plan.
Use an inline `display`, set when the mobile sheet opens and removed when it
closes: inline style beats a utility class without fighting `md:block`'s
specificity, and removing the property restores the class cleanly — a class
toggle would have to win at every viewport instead of just below the breakpoint.

- [ ] **Step 1: Write the failing spec**

```ruby
  # `matchMedia` observes the real viewport, so the window is really resized.
  # 375×667 is an iPhone SE; the breakpoint is `md`, 768px.
  context "below the md breakpoint" do
    before do
      page.driver.browser.manage.window.resize_to(375, 667)
      visit "/sidebar"
      wait_for_stimulus
    end

    after { page.driver.browser.manage.window.resize_to(1400, 900) }

    it "opens as a sheet, over the page and dismissable with Escape" do
      expect(find(sidebar, visible: :all)).not_to be_visible

      find(trigger).click

      expect(find(sidebar)).to be_visible
      expect(find(sidebar)["data-mobile"]).to eq("true")

      press(:escape)
      expect(find(sidebar, visible: :all)).not_to be_visible
    end

    it "does not write the desktop cookie" do
      find(trigger).click
      expect(find(sidebar)).to be_visible

      expect(page.evaluate_script("document.cookie")).not_to include("sidebar_state")
    end
  end
```

The second example is the one that matters most: upstream's `toggleSidebar`
moves `openMobile` on mobile and `open` on desktop (`sidebar.tsx:92-95`), so a
phone must not overwrite what the desktop remembered.

- [ ] **Step 2: Run them and watch them fail**

Run: `bundle exec rspec spec/system/sidebar_spec.rb -e "below the md breakpoint"`
Expected: FAIL — the first on the sidebar never becoming visible, since nothing
yet undoes `hidden`.

- [ ] **Step 3: Add the value and the media query**

```js
// The breakpoint is not a number this port chose: upstream's desktop tree
// carries `md:block` (vendor/shadcn/ui/sidebar.tsx:210), and `md` is 768px in
// Tailwind's default scale.
const MOBILE_QUERY = "(max-width: 767px)"
```

```js
  static values = { open: Boolean, openMobile: Boolean }
```

In `connect()`, before `this.render()`:

```js
    // Feature-detected the way `top_layer.js` treats the Popover API: without
    // matchMedia the desktop branch is the whole component.
    this.media = typeof window.matchMedia === "function" ? window.matchMedia(MOBILE_QUERY) : null
    this.onMediaChange = () => this.render()
    this.media?.addEventListener("change", this.onMediaChange)
```

and in `disconnect()`:

```js
    this.media?.removeEventListener("change", this.onMediaChange)
    this.closeMobile()
```

- [ ] **Step 4: Branch the toggle**

```js
  get isMobile() {
    return this.media?.matches === true
  }

  toggle() {
    // Upstream branches here rather than in the state: mobile moves an
    // ephemeral flag, desktop moves the persisted one
    // (vendor/shadcn/ui/sidebar.tsx:92-95).
    if (this.isMobile) {
      this.openMobileValue = !this.openMobileValue
    } else {
      this.openValue = !this.openValue
      this.persist()
    }

    this.render()
  }
```

- [ ] **Step 5: Give the same DOM the Sheet's behaviour**

```js
  render() {
    if (!this.hasSidebarTarget) return

    const sidebar = this.sidebarTarget

    sidebar.dataset.state = this.openValue ? "expanded" : "collapsed"
    sidebar.dataset.collapsible = this.openValue ? "" : (sidebar.dataset.sidebarCollapsible || "offcanvas")

    if (this.isMobile && this.openMobileValue) this.openMobile()
    else this.closeMobile()
  }

  // Everything a Sheet does, applied to markup the server already sent: the
  // element never moves, so the Stimulus actions on the links inside it stay
  // bound. `dialog_controller.js` composes the same three modules.
  openMobile() {
    const sidebar = this.sidebarTarget
    if (sidebar.dataset.mobile === "true") return

    sidebar.dataset.mobile = "true"
    // Undoes upstream's `hidden md:block`, which is CSS-hidden below the
    // breakpoint because React renders a different tree there. Inline beats the
    // utility without fighting `md:block` at other widths, and deleting the
    // property below restores the class exactly.
    sidebar.style.display = "block"

    topLayer.enable(sidebar)
    topLayer.show(sidebar)
    lockScroll()
    this.releaseFocus = trapFocus(sidebar, this.hasTriggerTarget ? this.triggerTarget : undefined)
    focusFirst(sidebar)
    this.layer = pushLayer({
      element: sidebar,
      // Without the trigger as an anchor, the very click that opens the sheet
      // reaches the dismiss layer as an outside click and closes it again.
      // `dialog_controller.js:67-69` passes it for the same reason.
      anchors: this.hasTriggerTarget ? [ this.triggerTarget ] : [],
      onDismiss: () => {
        this.openMobileValue = false
        this.render()
      }
    })
  }

  closeMobile() {
    const sidebar = this.sidebarTarget
    if (sidebar.dataset.mobile !== "true") return

    delete sidebar.dataset.mobile
    sidebar.style.removeProperty("display")

    topLayer.hide(sidebar)
    unlockScroll()
    this.releaseFocus?.()
    this.releaseFocus = null
    if (this.layer) removeLayer(this.layer)
    this.layer = null
  }
```

The signatures above are the real ones, checked rather than recalled:
`pushLayer({ element, anchors = [], onDismiss })` at `dismiss.js:58`,
`trapFocus(container, restoreTo = document.activeElement)` at `focus.js:35`,
`focusFirst(container)` at `:26`, and `lockScroll()` / `unlockScroll()` at
`:72` and `:80`, taking no arguments.

- [ ] **Step 6: Green, then verify by mutation**

Run: `bundle exec rspec spec/system/sidebar_spec.rb`
Expected: PASS, desktop examples included — resizing must not have broken them.

Two mutations, both required:

1. Remove `sidebar.style.display = "block"`. The first mobile example must fail
   on the sidebar never becoming visible. This is the line the design flagged as
   undecided, so it is the one most likely to be wrong.
2. Make `toggle()` always take the desktop branch (`if (false)`). The second
   example must fail with `sidebar_state` in the cookie.

Restore both and confirm `git diff` shows only the intended change.

- [ ] **Step 7: Commit**

```sh
bundle exec rake && bin/rubocop
git add app/javascript/shadcn test/dummy spec/system/sidebar_spec.rb
git commit -m "Give the Sidebar a Sheet's behaviour below md, in place"
```

---

### Task 6: Write down what this settled

**Files:**
- Modify: `.claude/docs/decisions/02-javascript.md`, `.claude/docs/todo.md`

- [ ] **Step 1: Record the decision**

In `02-javascript.md`, a section headed **The Sidebar keeps one tree and changes
its behaviour**. It must say, in prose: that shadcn renders three trees and picks
with `matchMedia`, which a server cannot do; that this port renders the desktop
tree and applies the Sheet's own modules to it below `md` without moving it,
because moving it would unbind the Stimulus actions inside — the same reason
nothing here is portalled; that the accepted cost is no sidebar on a phone before
JavaScript runs; and that `hidden md:block` is undone with an inline `display`
rather than a class, with the specificity reason.

Cite `vendor/shadcn/ui/sidebar.tsx:154` for the branch and `:210` for the class.

- [ ] **Step 2: Update `todo.md`**

The "Cases of their own" entry describes `sidebar` as 726 lines and unported.
Amend it rather than deleting it: the behaviour ships, the 24 components do not,
and the next branch is the eight structural parts followed by the sixteen leaves.

- [ ] **Step 3: Commit**

```sh
bundle exec rake && bin/rubocop
git add .claude/docs
git commit -m "Record how the Sidebar replaces its runtime branch"
```

---

## What this plan does not do

- **Any of the 24 ViewComponents.** The markup that exists is a fixture in the
  dummy app and is not shipped by the gem.
- **`collapsible: "none"` and the `icon` variant.** The contract page renders
  `offcanvas`; the other two are class-only and belong with the components.
- **Server-side viewport detection.** A host may do it and pass `open:`; the gem
  takes no position.
- **An exit animation for the mobile sheet.** `dialog_controller.js` runs its
  closes through `ExitQueue`; this one hides immediately. Worth adding when the
  components land and the sheet has real animation classes on it — with nothing
  animating, `ExitQueue` would take its synchronous branch anyway.
