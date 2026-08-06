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
end
