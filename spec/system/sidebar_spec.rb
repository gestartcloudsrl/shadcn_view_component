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
end
