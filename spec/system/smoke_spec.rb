# frozen_string_literal: true

require "spec_helper"

RSpec.describe "the gallery boots" do
  it "loads a preview with the stylesheet and the controllers registered" do
    visit_preview(:button, :variants)
    wait_for_stimulus

    registered = page.evaluate_script(
      "Stimulus.router.modules.map(m => m.definition.identifier).sort()"
    )

    expect(registered).to include("shadcn--dialog", "shadcn--select", "shadcn--theme")
    expect(page).to have_button("Default")

    # The compiled Tailwind is actually applied, not just linked.
    background = page.evaluate_script(
      "getComputedStyle(document.querySelector('[data-slot=button]')).backgroundColor"
    )
    expect(background).not_to eq("rgba(0, 0, 0, 0)")
  end

  # Every family that has a controller, loaded for real. A controller that
  # throws in `connect()` — the `crypto.randomUUID()` bug, say — leaves the
  # component silently dead, and nothing else in the suite would notice.
  %w[
    accordion collapsible tabs dialog alert_dialog sheet dropdown_menu popover
    tooltip select checkbox switch radio_group toggle toggle_group avatar
    mode_toggle mode_switcher theme_selector
  ].each do |family|
    it "loads #{family} without a JavaScript error" do
      visit_preview(family)
      wait_for_stimulus

      errors = page.driver.browser.logs.get(:browser).reject { |log| log.level == "WARNING" }

      expect(errors.map(&:message)).to be_empty
      expect(page).to have_css("[data-controller]", visible: :all)
    end
  end
end
