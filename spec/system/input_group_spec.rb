# frozen_string_literal: true

require "spec_helper"

RSpec.describe "InputGroup", :js do
  # Lazy, so it reads the DOM after the example's click rather than before it.
  let(:focused_placeholder) do
    page.evaluate_script("document.activeElement.getAttribute('placeholder')")
  end

  before do
    visit_preview(:input_group)
    wait_for_stimulus
  end

  # The whole bordered box should behave like the input it wraps, which is the
  # one piece of behaviour upstream gives this family.
  context "when an addon is clicked" do
    it "focuses the group's control" do
      first("[data-slot=input-group-addon]").click

      expect(focused_placeholder).to eq("example.com")
    end
  end

  # A click that landed on a button is what the user meant; stealing the focus
  # would swallow the action.
  context "when the click lands on a button inside the addon" do
    it "leaves the focus alone" do
      within(all("[data-slot=input-group]")[1]) { click_button "Go" }

      expect(focused_placeholder).not_to eq("Search")
    end
  end
end
