# frozen_string_literal: true

require "spec_helper"

# Every `data-[state=closed]:animate-out` class in the port used to be inert:
# closing set `hidden` in the same tick that set `data-state="closed"`, and
# `[data-slot][hidden] { display: none !important }` removed the element before a
# frame could paint. These examples are what stops that coming back.
#
# The animation assertions read what the browser *scheduled*, never what is on
# screen at a given moment, so those do not race. The presence assertions do:
# `have_css`/`have_no_css` retry for up to `Capybara.default_max_wait_time`, so
# they only hold because `force_animations` keeps the forced duration under it.
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
    end

    context "when closed" do
      before do
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

      it "sets closed state and aria-expanded synchronously, before the animation finishes" do
        expect(state_of(content)).to eq("closed")
        expect(trigger["aria-expanded"]).to eq("false")
      end
    end

    # The gallery header carries a ThemeSelector, itself a Select and so a
    # second dismissable layer. Opening it before the popover puts it beneath
    # the popover on `dismiss.js`'s stack, which is what makes the second
    # Escape below meaningful: it only reaches the selector if the popover
    # already gave up its spot on the stack, rather than waiting for its exit
    # animation to finish.
    context "with another dismissable layer open behind it" do
      before do
        find("[data-slot=select-trigger]").click
        expect(page).to have_css("[data-slot=select-content]", visible: :all)

        # A keyboard activation, not a click: opening the popover this way never
        # fires `pointerdown`, so it does not trip `dismiss.js`'s outside-click
        # check and close the select before either Escape below is pressed.
        page.execute_script("document.querySelector('[data-slot=popover-trigger]').focus()")
        press(:enter)
        expect(page).to have_css(content)
        press(:escape)
      end

      it "lets a second Escape reach the layer behind it" do
        press(:escape)

        expect(state_of("[data-slot=select-content]")).to eq("closed")
      end
    end
  end

  # Tooltip opens and closes on hover, so reopening before an exit has settled
  # is its common path, not an edge case.
  describe "reopening a layer before its exit finishes" do
    let(:content) { "[data-slot=tooltip-content]" }

    def trigger = find("[data-slot=tooltip-trigger]")

    # A generous duration, not the shared 400ms: reaching this point already
    # cost a hover, a click and two round trips to the browser, and reopening
    # has to still land inside the exit window afterwards.
    before do
      visit_preview(:tooltip)
      wait_for_stimulus
      force_animations(content, duration: "3s")
      trigger.hover
      expect(page).to have_css(content)
      click_outside # moves the pointer away, starting the exit
      expect(page).to have_css(content) # still fading, not yet dismounted
    end

    it "reuses the pending wrapper and clears the exiting marker, instead of nesting a second one" do
      trigger.hover

      expect(page).to have_css("[data-radix-popper-content-wrapper]", count: 1, visible: :all)
      expect(page).to have_no_css("#{content}[data-exiting]", visible: :all)

      # The cancelled exit's own continuation resolves within a microtask, well
      # under this: without `cancel()`, it would still dismount the reopened
      # content out from under the hover that just brought it back.
      sleep 0.2
      expect(page).to have_css(content)
    end
  end
end
