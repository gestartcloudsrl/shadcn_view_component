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
# A property read taken while an animation is still expected to be running is a
# third case, covered by neither: there is no retry to save it, so it only
# holds because the forced duration comfortably outlasts the round trip to read
# it — see the accordion's height assertions below, forced to 3s for that
# reason.
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

    # Dialog content is `duration-200` (sheet content `duration-300`); the
    # overlay carries no `duration-*` class and falls back to `animate-out`'s
    # default of 150ms — forced to 200ms above so it still outlives the
    # content in this example. One shared wait would hold whichever finishes
    # first on screen past its own animation, so each element waits on its
    # own.
    it "lets the overlay finish before the content" do
      expect(page).to have_no_css(overlay)
      expect(page).to have_css(content)
      expect(page).to have_no_css(content)

      # `have_no_css` alone would also pass if `hidden` were never set:
      # `hidePopover()`'s own UA style already yields `display: none`.
      expect(page.evaluate_script("document.querySelector('#{overlay}').hidden")).to be(true)
      expect(page.evaluate_script("document.querySelector('#{content}').hidden")).to be(true)
    end

    it "gives focus back and unlocks scrolling without waiting" do
      expect(page.evaluate_script("document.activeElement.dataset.slot")).to eq("dialog-trigger")
      expect(page.evaluate_script("document.body.style.overflow")).to eq("")
    end

    it "does not intercept clicks while it fades" do
      expect(page.evaluate_script("getComputedStyle(document.querySelector('#{overlay}')).pointerEvents"))
        .to eq("none")
    end

    # `have_no_css` only proves the overlay stopped painting, which `hidden`
    # alone already guarantees. Leaving it a popover the browser still
    # considers open is what would let a later `showPopover()` throw and get
    # swallowed instead of actually moving it — the failure mode below.
    it "takes the overlay out of the top layer once its exit finishes, not just out of the render" do
      expect(page).to have_no_css(overlay)

      expect(page.evaluate_script("document.querySelector('#{overlay}').matches(':popover-open')")).to be(false)
    end
  end

  describe "the accordion" do
    # The preview is `collapsible: true` with `item-1` already open, so the
    # animated transition is its trigger being clicked once.
    let(:content) { "[data-value=item-1] [data-slot=accordion-content]" }

    # 3s, not the shared 400ms: the height assertions below take a
    # moment-in-time read rather than something Capybara retries, so the
    # forced duration has to still be running when the round trip to read it
    # lands.
    before do
      visit_preview(:accordion)
      wait_for_stimulus
      force_animations(content, duration: "3s")
    end

    def height_now
      page.evaluate_script(
        "document.querySelector('#{content}')" \
        ".style.getPropertyValue('--radix-accordion-content-height')"
      )
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
      # that no longer exists; leaving it published after landing is an
      # orphan custom property on a panel with nothing left animating.
      #
      # `have_no_css` cannot gate the landing here the way it does for a fade:
      # `accordion-up` animates a real `height`, so WebDriver already reports
      # the panel as not displayed at its zero-height last frame — before the
      # teardown that actually clears the property has run. The `hidden`
      # attribute is set in that same teardown call, so waiting on it directly
      # means the property is already gone by the time this reads it.
      it "keeps the height it is collapsing towards until it lands" do
        expect(height_now).not_to be_empty

        expect(page).to have_css("#{content}[hidden]", visible: :all)

        expect(height_now).to be_empty
      end
    end

    context "when reopened before the collapse finishes" do
      before do
        expect(page).to have_css(content)
        click_button "Is it accessible?" # starts the collapse
        click_button "Is it accessible?" # reopens mid-exit
      end

      it "keeps the panel open instead of the cancelled collapse's stale teardown dismounting it" do
        # Reopening flips `data-state` back to open, which cancels the running
        # `accordion-up` and rejects `finished` — the deferred teardown's own
        # continuation still resolves and, without `cancel()`, would flush
        # once it drains: well under this sleep, since it settles within a
        # microtask.
        sleep 0.2

        expect(page).to have_css(content)
      end
    end
  end

  # The overlay carries no `duration-*` class, so `animate-out`'s 150ms
  # default applies, while alert dialog content is `duration-200` — the
  # overlay always leaves the top layer first. Reopening in that window used
  # to restack the overlay above the content instead of below: `showPopover()`
  # on the overlay re-adds it fresh to the top of the stack, while
  # `showPopover()` on the still-open content throws (it was never actually
  # hidden) and is swallowed, leaving the content at its old, lower slot.
  describe "reopening after the overlay has left the top layer but before the content has" do
    let(:content) { "[data-slot=alert-dialog-content]" }
    let(:overlay) { "[data-slot=alert-dialog-overlay]" }

    before do
      visit_preview(:alert_dialog)
      wait_for_stimulus
      force_animations(overlay, duration: "50ms")
      force_animations(content, duration: "3s")
      click_button "Delete account"
      expect(page).to have_css(content)
      press(:escape)

      # The overlay's own exit has finished and taken it out of the top
      # layer; the content — forced far longer — is still mid-exit.
      expect(page).to have_no_css("#{overlay}[data-exiting]", visible: :all)
      expect(page).to have_css("#{content}[data-exiting]", visible: :all)

      click_button "Delete account"
    end

    it "keeps the content above the overlay instead of restacking it underneath" do
      expect(page.evaluate_script(<<~JS)).to be(true)
        !!document.elementFromPoint(window.innerWidth / 2, window.innerHeight / 2)?.closest("#{content}")
      JS
    end

    # AlertDialog refuses to dismiss on an outside click, so a wrongly-stacked
    # overlay leaves no way out at all: a backdrop the user cannot see
    # through, over a dialog they cannot reach.
    it "still reaches the content with a click, instead of the overlay swallowing it" do
      within(content) { click_button "Cancel" }

      expect(page).to have_no_css(content)
    end

    # Without `cancel()`, the exit's own continuation — settled by the state
    # flip cancelling the running animation, not by this call — still
    # resolves and flushes the stale teardown once it does, dismounting the
    # dialog that just reopened.
    it "keeps the reopened content on screen once the original exit would otherwise have finished" do
      sleep 0.5

      expect(page).to have_css(content)
    end
  end
end
