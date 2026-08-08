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
    expect(find(sidebar)["data-collapsible"]).to eq("offcanvas")

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
end
