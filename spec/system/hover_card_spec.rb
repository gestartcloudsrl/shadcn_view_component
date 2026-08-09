# frozen_string_literal: true

require "spec_helper"

# The delays are the component. A tooltip appears and vanishes with the pointer;
# a hover card is meant to be *entered*, which only works if leaving the trigger
# starts a close the card can cancel by being arrived at.
#
# Driven with `pointerenter`/`pointerleave` rather than Capybara's `hover`,
# which moves a real pointer and cannot be aimed at the gap between two
# elements — and the gap is the thing under test.
RSpec.describe "Hover card", :js do
  let(:trigger) { "[data-slot=hover-card-trigger]" }
  let(:card) { "[data-slot=hover-card-content]" }

  def point(selector, event, pointer_type: "mouse")
    page.execute_script(<<~JS)
      document.querySelector(#{selector.to_json}).dispatchEvent(
        new PointerEvent(#{event.to_json}, { bubbles: false, pointerType: #{pointer_type.to_json} })
      )
    JS
  end

  # The shipped delays are 700ms and 300ms. Left alone, every example below
  # would be at the mercy of Capybara's wait window rather than asserting
  # anything, so the ones about *behaviour* shorten them and the one about the
  # values reads the untouched markup.
  #
  # `setAttribute`, not `dataset`. The attribute is
  # `data-shadcn--hover-card-open-delay-value` and `dataset` cannot address a
  # double hyphen: assigning `dataset.shadcnHoverCardOpenDelayValue` writes a
  # *different* attribute and leaves the controller reading 700. Two mutations
  # survived this suite while it did that — one re-opening the card at 700ms
  # after closing it at 300, the other simply not opening before the assertion.
  def speed_up(open_delay: 50, close_delay: 300)
    page.execute_script(<<~JS)
      const root = document.querySelector("[data-slot=hover-card]")
      root.setAttribute("data-shadcn--hover-card-open-delay-value", #{open_delay.to_json})
      root.setAttribute("data-shadcn--hover-card-close-delay-value", #{close_delay.to_json})
    JS
  end

  before do
    visit_preview(:hover_card)
    wait_for_stimulus
  end

  it "ships Radix's own delays" do
    root = find("[data-slot=hover-card]", visible: :all)

    expect(root["data-shadcn--hover-card-open-delay-value"]).to eq("700")
    expect(root["data-shadcn--hover-card-close-delay-value"]).to eq("300")
  end

  it "opens under the pointer and closes when it leaves" do
    speed_up
    expect(page).to have_css(card, visible: :hidden)

    point(trigger, "pointerenter")
    expect(page).to have_css("#{card}[data-state=open]", visible: :visible)

    point(trigger, "pointerleave")
    expect(page).to have_css(card, visible: :hidden)
  end

  # The example that earns the component. Leaving the trigger starts a close;
  # arriving on the card has to cancel it, or the card is unreachable and the
  # links in it might as well not be there.
  it "stays open when the pointer moves from the trigger onto the card" do
    speed_up
    point(trigger, "pointerenter")
    expect(page).to have_css("#{card}[data-state=open]", visible: :visible)

    point(trigger, "pointerleave")
    point(card, "pointerenter")

    # Well past the 300ms close, so a cancel that did not happen has had every
    # chance to fire — and past the 50ms open too, so a close that fired cannot
    # be papered over by a re-open.
    sleep 0.8
    expect(page).to have_css("#{card}[data-state=open]", visible: :visible)

    point(card, "pointerleave")
    expect(page).to have_css(card, visible: :hidden)
  end

  # Radix opens on focus and closes on blur, which is the only way a keyboard
  # reaches this at all (hover-card.tsx:138-141).
  it "opens from the keyboard, and marks the trigger either way" do
    speed_up
    expect(find(trigger)["data-state"]).to eq("closed")

    page.execute_script("document.querySelector(#{trigger.to_json}).focus()")
    expect(page).to have_css("#{card}[data-state=open]", visible: :visible)
    expect(find(trigger)["data-state"]).to eq("open")

    page.execute_script("document.querySelector(#{trigger.to_json}).blur()")
    expect(page).to have_css(card, visible: :hidden)
  end

  # A tap is not a hover. Radix excludes touch pointers (`excludeTouch`),
  # because on a touch screen the gesture that would open the card is the same
  # one trying to follow the link it hangs off.
  it "ignores a touch pointer" do
    speed_up
    point(trigger, "pointerenter", pointer_type: "touch")

    # Comfortably past the 50ms open, so "nothing happened" is a result rather
    # than a race.
    sleep 0.4
    expect(page).to have_css(card, visible: :hidden)
  end

  # The card cannot be tabbed into, so nothing in it may be a tab stop.
  it "takes everything inside the card out of the tab order" do
    speed_up
    point(trigger, "pointerenter")
    expect(page).to have_css("#{card}[data-state=open]", visible: :visible)

    tabbables = page.evaluate_script(<<~JS)
      Array.from(
        document.querySelector(#{card.to_json})
          .querySelectorAll("a[href], button, input, select, textarea")
      ).map((element) => element.getAttribute("tabindex"))
    JS

    expect(tabbables).not_to be_empty
    expect(tabbables).to all(eq("-1"))
  end
end
