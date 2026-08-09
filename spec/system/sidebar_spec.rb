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

    it "opens as a sheet over the page, and Escape dismisses it" do
      expect(page).to have_css(sidebar, visible: :hidden)

      find(trigger).click

      expect(page).to have_css(sidebar, visible: :visible)
      expect(find(sidebar)["data-mobile"]).to eq("true")

      press(:escape)

      expect(page).to have_css(sidebar, visible: :hidden)
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
