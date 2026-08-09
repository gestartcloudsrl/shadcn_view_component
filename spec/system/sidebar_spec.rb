# frozen_string_literal: true

require "spec_helper"

# The Sidebar's behaviour, driven from a hand-written page rather than from
# components: none exist yet, and this markup is the contract the 24 of them
# will have to satisfy. See specs/2026-08-08-sidebar-mobile-rendering-design.md.
RSpec.describe "Sidebar", :js do
  let(:sidebar) { "[data-slot=sidebar]" }
  let(:trigger) { "[data-slot=sidebar-trigger]" }

  # `press` sends its arguments in sequence, not as a chord: measured, an array
  # arrives as Meta down-and-up followed by a bare "b" with `metaKey: false`.
  # A modifier combination has to be held open explicitly.
  def press_with_meta(key)
    page.driver.browser.action.key_down(:meta).send_keys(key).key_up(:meta).perform
  end

  before do
    visit "/sidebar"
    wait_for_stimulus
  end

  it "renders expanded, with the attributes its classes read" do
    expect(page).to have_css("#{sidebar}[data-state=expanded]")
    expect(find(sidebar)["data-side"]).to eq("left")
    expect(find(sidebar)["data-variant"]).to eq("sidebar")
  end

  # `data-collapsible` is the attribute every collapsed-state class matches on,
  # and upstream leaves it *empty* while expanded (sidebar.tsx:212). Filling it
  # unconditionally would style an open sidebar as a closed one, which is why
  # this asserts the empty string rather than just the state.
  it "collapses and expands, and fills data-collapsible only while collapsed" do
    expect(find(sidebar)["data-collapsible"]).to eq("")

    find(trigger).click
    expect(page).to have_css("#{sidebar}[data-state=collapsed]")
    # The page renders `collapsible: :icon`, which is what upstream's demo uses,
    # so this is the value the controller must fill in — read from
    # `data-sidebar-collapsible`, never guessed.
    expect(find(sidebar)["data-collapsible"]).to eq("icon")

    find(trigger).click
    expect(page).to have_css("#{sidebar}[data-state=expanded]")
    expect(find(sidebar)["data-collapsible"]).to eq("")
  end

  # Written so a Rails layout can render the sidebar already collapsed. Without
  # it the server always sends the default and the client corrects it after
  # Stimulus boots, which on this component is a full-width layout shift rather
  # than a repaint. The component never reads it back — that is the host's job,
  # exactly as upstream leaves it (sidebar.tsx:86).
  it "remembers the collapsed state in a cookie the server can read" do
    find(trigger).click
    expect(page).to have_css("#{sidebar}[data-state=collapsed]")

    expect(page.evaluate_script("document.cookie")).to include("sidebar_state=false")

    find(trigger).click
    expect(page).to have_css("#{sidebar}[data-state=expanded]")

    expect(page.evaluate_script("document.cookie")).to include("sidebar_state=true")
  end

  # Bound on `window`, so it works from anywhere on the page rather than only
  # while the trigger has focus (sidebar.tsx:96-111). The last assertion is the
  # one that earns the example: a bare "b" is a character somebody may be
  # typing, and a shortcut that swallows it would be worse than none.
  it "toggles from anywhere with the shortcut, and leaves a plain b alone" do
    press_with_meta("b")
    expect(page).to have_css("#{sidebar}[data-state=collapsed]")

    press_with_meta("b")
    expect(page).to have_css("#{sidebar}[data-state=expanded]")

    press("b")
    expect(page).to have_css("#{sidebar}[data-state=expanded]")
  end

  # The tooltip labels a menu row once the panel is a rail of icons, so it is
  # positioned against a button that changes width underneath it: hovering a row
  # opens the tooltip — CSS-hidden while expanded — and the shortcut then shrinks
  # that button from the panel's width to the icon's without the pointer ever
  # moving off it. Nothing in `resize` or `scroll` fires for that, which left the
  # label stranded where the wide button used to end. floating-ui repositions
  # because `autoUpdate` observes the reference element; `FloatingLayer` observes
  # the anchor for the same reason.
  #
  # Driven from focus rather than hover, which is the keyboard user's route
  # through it — Tab to a row, then the shortcut — and the only one where the
  # tooltip survives the collapse: a pointer resting on a 239px row is outside
  # the 32px button it becomes, so hovering closes the tooltip on the way and
  # proves nothing. `focus` is the same event Tab raises.
  it "keeps a tooltip on its anchor when the panel collapses under it" do
    button = find("[data-slot=sidebar-menu-button]", text: "Models")
    page.execute_script("arguments[0].focus()", button.native)

    press_with_meta("b")
    expect(page).to have_css("#{sidebar}[data-state=collapsed]")

    label = find("[data-slot=tooltip-content]", text: "Models")

    # The tooltip is unhidden by `data-state=collapsed` landing, but moved a
    # frame later, when the observer's `requestAnimationFrame` runs — so it is
    # briefly visible in the wrong place, and reading `rect` once races that.
    # `synchronize` retries the measurement instead, which is the same fix
    # `have_css(..., visible:)` was to `be_visible` elsewhere in this suite.
    page.document.synchronize do
      gap = label.rect.x - (button.rect.x + button.rect.width)
      next if gap.between?(0, 8)

      raise Capybara::ExpectationNotMet, "the tooltip sits #{gap}px from its anchor"
    end
  end

  # `matchMedia` observes the real viewport, so the window is really resized.
  # 375×667 is an iPhone SE; the breakpoint is `md`, which upstream's own
  # desktop tree names in its `md:block` (sidebar.tsx:210).
  #
  # Assertions use `have_css(..., visible:)` rather than `be_visible`, which
  # reads once and races whatever is about to change it.
  context "when the viewport is below the md breakpoint" do
    before do
      page.driver.browser.manage.window.resize_to(375, 667)
      visit "/sidebar"
      wait_for_stimulus
    end

    after { page.driver.browser.manage.window.resize_to(1400, 900) }

    # Asserted on `sidebar-container` rather than on `sidebar`, and that is the
    # whole point of the example. The flag and the inline `display` land on the
    # outer element, so it turns visible whether or not anything inside it does
    # — and for as long as this suite has existed, nothing did: the container
    # carries its own `hidden … md:flex`, which the breakpoint it names can only
    # ever switch off *above* `md`. The sheet opened onto an empty strip and
    # every assertion here passed.
    it "opens as a sheet over the page, and Escape dismisses it" do
      expect(page).to have_css(sidebar, visible: :hidden)

      find(trigger).click

      expect(page).to have_css("[data-slot=sidebar-container]", visible: :visible)
      expect(find(sidebar)["data-mobile"]).to eq("true")
      # `SIDEBAR_WIDTH_MOBILE`, 18rem (sidebar.tsx:31) — upstream applies it by
      # overriding `--sidebar-width` on the Sheet; there is no second element
      # here, so the panel reads `--sidebar-width-mobile` instead.
      expect(find("[data-slot=sidebar-container]").rect.width.round).to eq(288)

      press(:escape)

      expect(page).to have_css(sidebar, visible: :hidden)
    end

    # `top_layer.enable` sets `popover="manual"`, and the UA gives `[popover]`
    # `position: fixed` whether it is showing or not. `shadcn.css` neutralises
    # the rest of those defaults and deliberately not that one, because every
    # other caller enables it on a wrapper that is fixed anyway. This is the one
    # element the page is laid out *around*, so leaving it enabled left the
    # desktop sidebar out of flow and the page drawn straight over it.
    it "returns the panel to the page's flow once the sheet has been closed" do
      find(trigger).click
      expect(page).to have_css("[data-slot=sidebar-container]", visible: :visible)

      press(:escape)
      expect(page).to have_css(sidebar, visible: :hidden)

      page.driver.browser.manage.window.resize_to(1400, 900)
      expect(page).to have_css("#{sidebar}[data-state=expanded]")

      # `visible: :all` because the gap is a spacer with no content: it has the
      # panel's width and no height, which Selenium reports as not displayed.
      # Its width is exactly what is being measured.
      page.document.synchronize do
        gap = find("[data-slot=sidebar-gap]", visible: :all).rect
        inset = find("[data-slot=sidebar-inset]", visible: :all).rect
        next if inset.x >= gap.x + gap.width

        raise Capybara::ExpectationNotMet,
              "the page starts at #{inset.x}, over a sidebar ending at #{gap.x + gap.width}"
      end
    end

    # Upstream's mobile branch is a real `Sheet`, so the dimmed backdrop and the
    # slide come with it (sheet.tsx:39 and :63-67). Here the sheet *is* this
    # panel: the overlay ships hidden in the server's markup — it is the gem's
    # own `sheet-overlay`, so a host styling that slot reaches this one — and
    # the slide is keyed on the container's own `data-state`, which nothing but
    # the mobile branch ever writes.
    it "dims the page behind the sheet, and slides the panel in" do
      expect(page).to have_css("[data-slot=sheet-overlay]", visible: :hidden)

      find(trigger).click

      expect(page).to have_css("[data-slot=sheet-overlay][data-state=open]", visible: :visible)
      expect(find("[data-slot=sidebar-container]")["data-state"]).to eq("open")

      press(:escape)

      expect(page).to have_css("[data-slot=sheet-overlay]", visible: :hidden)
    end

    # Clicking the dimmed backdrop is how a sheet is usually closed, and adding
    # the overlay is what broke it: it is a *child* of `sidebar`, so a dismiss
    # layer registered on `sidebar` read a click on the backdrop as a click
    # inside itself. Upstream never meets this — its overlay is the content's
    # sibling, portalled beside it — so the layer here is registered on the
    # panel, the half that is not the backdrop.
    it "closes when the dimmed backdrop is clicked" do
      find(trigger).click
      expect(page).to have_css("[data-slot=sheet-overlay][data-state=open]", visible: :visible)

      # Offset from the centre, because the centre of a full-viewport backdrop
      # is behind the panel: at 375 wide with an 18rem sheet, the part a finger
      # can actually reach is the strip to its right.
      find("[data-slot=sheet-overlay]").click(x: 150, y: 0)

      expect(page).to have_css(sidebar, visible: :hidden)
    end

    # The close is what the animation is for, and what makes it possible to get
    # wrong: `data-mobile` going away is what re-hides the container, so
    # removing it in the same tick as `data-state="closed"` would take the panel
    # off screen before a frame of the slide-out could paint — which is exactly
    # how every `animate-out` in this port was inert once before
    # (`exit_animation_spec.rb`). Pinned mid-exit against a forced duration.
    it "keeps the sheet on screen until its slide-out has played" do
      find(trigger).click
      expect(page).to have_css("[data-slot=sidebar-container]", visible: :visible)
      force_animations("[data-slot=sidebar-container]", duration: "3s")

      press(:escape)

      expect(find(sidebar)["data-mobile"]).to eq("true")
      expect(find("[data-slot=sidebar-container]")["data-state"]).to eq("closed")
      # Interaction state does not wait: a sheet on its way out answers nothing.
      expect(page).to have_no_css("[data-slot=sidebar-container][data-state=open]")
    end

    # The backdrop is hidden on its own clock, not the panel's. Nothing in the
    # compiled bundle sets `animation-fill-mode` — `reduced_motion_spec.rb` reads
    # that same bundle — so an element sits at its *pre-animation* state the
    # moment its keyframes end. Hiding the overlay when the panel finished left
    # it snapping back to a full `bg-black/50` over an empty page for the
    # difference between the two durations.
    #
    # Forced to 3s against the panel's 400ms so the two clocks are unmistakably
    # apart, and read after the shorter one: with the defect the overlay is
    # still there, opaque again.
    it "takes the backdrop away on its own clock, not the panel's" do
      find(trigger).click
      expect(page).to have_css("[data-slot=sheet-overlay]", visible: :visible)

      force_animations("[data-slot=sheet-overlay]", duration: "400ms")
      force_animations("[data-slot=sidebar-container]", duration: "3s")

      press(:escape)

      # `visible: :hidden` rather than the absence of a visible one: Selenium
      # reads `display`, and an overlay mid-fade is opaque or transparent
      # without either counting as hidden. What is being asserted is the
      # `hidden` attribute the controller sets, which `[data-slot][hidden]`
      # turns into `display: none`.
      expect(page).to have_css("[data-slot=sheet-overlay]", visible: :hidden)
      # The panel is still on its way out, which is what makes the overlay's
      # absence meaningful rather than merely simultaneous.
      expect(find(sidebar)["data-mobile"]).to eq("true")
    end

    # The one that matters most. Upstream's toggleSidebar moves `openMobile` on
    # mobile and `open` on desktop (sidebar.tsx:92-95), so opening the sheet on
    # a phone must not overwrite what the desktop remembered.
    it "does not write the desktop cookie" do
      find(trigger).click
      expect(page).to have_css(sidebar, visible: :visible)

      expect(page.evaluate_script("document.cookie")).not_to include("sidebar_state")
    end
  end
end
