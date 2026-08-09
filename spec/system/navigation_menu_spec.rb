# frozen_string_literal: true

require "spec_helper"

# One panel open at a time, belonging to a trigger. Everything interesting is
# about *when*: a menu that opened the instant a pointer crossed it would flash
# panels at anyone sweeping past, and one that always waited would feel stuck
# once you were already inside it.
#
# Driven with `pointerenter`/`pointerleave` rather than Capybara's `hover`,
# which moves a real pointer and cannot be aimed at the gap between a trigger
# and its panel — and that gap is what the closing delay exists for.
RSpec.describe "Navigation menu", :js do
  let(:trigger) { "[data-slot=navigation-menu-trigger]" }
  let(:content) { "[data-slot=navigation-menu-content]" }

  def point(element, event, pointer_type: "mouse")
    page.execute_script(<<~JS, element)
      arguments[0].dispatchEvent(
        new PointerEvent(#{event.to_json}, { bubbles: false, pointerType: #{pointer_type.to_json} })
      )
    JS
  end

  # The shipped delays are 200ms and 300ms. Behaviour examples shorten the
  # opening one so they assert rather than wait; the example about the values
  # reads the untouched markup. `setAttribute`, never `dataset` — the attribute
  # has a double hyphen, which `dataset` cannot address, and a spec that got
  # that wrong let three mutations through on the hover card.
  def speed_up(delay: 0, skip_delay: 300)
    page.execute_script(<<~JS)
      const root = document.querySelector("[data-slot=navigation-menu]")
      root.setAttribute("data-shadcn--navigation-menu-delay-value", #{delay.to_json})
      root.setAttribute("data-shadcn--navigation-menu-skip-delay-value", #{skip_delay.to_json})
    JS
  end

  def triggers = all(trigger)

  # Read, not waited for. Every example about *timing* here has to sample the
  # state at a chosen moment; a retrying matcher would answer "eventually",
  # which is the one thing none of them is asking.
  def state_of_first_panel = all(content, visible: :all).first["data-state"]

  before do
    visit_preview(:navigation_menu)
    wait_for_stimulus
  end

  it "ships Radix's own delays" do
    root = find("[data-slot=navigation-menu]")

    expect(root["data-shadcn--navigation-menu-delay-value"]).to eq("200")
    expect(root["data-shadcn--navigation-menu-skip-delay-value"]).to eq("300")
  end

  # This port renders `data-viewport="false"` and nothing else, and it is not a
  # detail: half of the content's classes only apply in that mode, and the
  # shared viewport is what could not be reproduced without portalling.
  it "declares the configuration it reproduces" do
    expect(find("[data-slot=navigation-menu]")["data-viewport"]).to eq("false")
    expect(page).to have_no_css("[data-slot=navigation-menu-viewport]", visible: :all)
  end

  it "opens a panel under its trigger and marks the trigger expanded" do
    speed_up
    expect(page).to have_css("#{content}[data-state=closed]", visible: :all)

    point(triggers.first, "pointerenter")

    expect(page).to have_css("#{content}[data-state=open]", visible: :visible)
    expect(triggers.first["aria-expanded"]).to eq("true")
  end

  # The panel is a sibling of the trigger, not a child, so moving onto it is
  # leaving the trigger. Without a closing delay that arrival never happens.
  it "stays open when the pointer moves from the trigger onto the panel" do
    speed_up
    point(triggers.first, "pointerenter")
    expect(page).to have_css("#{content}[data-state=open]", visible: :visible)

    panel = find(content, match: :first)
    point(triggers.first, "pointerleave")
    point(panel, "pointerenter")

    sleep 0.5
    expect(page).to have_css("#{content}[data-state=open]", visible: :visible)
  end

  it "closes when the pointer leaves the panel" do
    speed_up
    point(triggers.first, "pointerenter")
    expect(page).to have_css("#{content}[data-state=open]", visible: :visible)

    point(find(content, match: :first), "pointerleave")

    expect(page).to have_css("#{content}[data-state=closed]", visible: :all)
  end

  # Only one at a time, and the second knows which side the first was on — the
  # pair slides rather than swapping.
  it "swaps panels and records which way it moved" do
    speed_up
    point(triggers.first, "pointerenter")
    expect(page).to have_css("#{content}[data-state=open]", visible: :visible)

    point(triggers[1], "pointerenter")

    open_panels = all("#{content}[data-state=open]", visible: :visible)
    expect(open_panels.size).to eq(1)
    expect(open_panels.first["data-motion"]).to eq("from-end")

    point(triggers.first, "pointerenter")
    expect(all("#{content}[data-state=open]", visible: :visible).first["data-motion"])
      .to eq("from-start")
  end

  # A pointer crossing a trigger on its way somewhere else must not open
  # anything. That is the whole of what the opening delay is for, and it can
  # only be asserted by *reading* the state at a moment rather than waiting for
  # it: `have_css` retries for two seconds, so a 400ms delay satisfies it and
  # the assertion says nothing.
  it "does not open for a pointer that crosses and leaves" do
    speed_up(delay: 400)

    point(triggers.first, "pointerenter")
    point(triggers.first, "pointerleave")

    # Sampled *before* the 400ms open would have fired, which is the only
    # moment that distinguishes "never opened" from "opened and closed again":
    # leaving also schedules a close, so a panel that opened instantly is shut
    # by the time a later read arrives, and the assertion passes for the wrong
    # reason. It did.
    sleep 0.1

    expect(state_of_first_panel).to eq("closed")
  end

  # The other half: having waited once, you should not wait again. Read at a
  # moment between the two delays, so "opened at once" and "still waiting" are
  # different answers rather than the same one arrived at late.
  it "opens at once inside the grace period after a panel closes" do
    speed_up(delay: 400, skip_delay: 2000)

    point(triggers.first, "pointerenter")
    expect(page).to have_css("#{content}[data-state=open]", visible: :visible)

    point(triggers.first, "pointerleave")
    expect(page).to have_css("#{content}[data-state=closed]", visible: :all)

    point(triggers[1], "pointerenter")
    sleep 0.15

    expect(all(content, visible: :all)[1]["data-state"]).to eq("open")
  end

  describe "from the keyboard" do
    it "moves between triggers with the arrows" do
      triggers.first.click
      page.execute_script("document.querySelector(#{trigger.to_json}).focus()")

      triggers.first.send_keys(:arrow_right)

      expect(page.evaluate_script("document.activeElement.textContent.trim()"))
        .to start_with(triggers[1].text.strip.split.first)
    end

    # The panel is under its trigger, not after it, so Tab does not reach the
    # links. Down is the way in.
    it "steps into the panel with ArrowDown" do
      speed_up
      triggers.first.send_keys(:arrow_down)

      expect(page).to have_css("#{content}[data-state=open]", visible: :visible)
      expect(page.evaluate_script("document.activeElement.dataset.slot"))
        .to eq("navigation-menu-link")
    end

    it "closes on Escape and puts focus back on the trigger" do
      speed_up
      point(triggers.first, "pointerenter")
      expect(page).to have_css("#{content}[data-state=open]", visible: :visible)

      page.execute_script("document.body.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }))")

      expect(page).to have_css("#{content}[data-state=closed]", visible: :all)
      expect(page.evaluate_script("document.activeElement.dataset.slot"))
        .to eq("navigation-menu-trigger")
    end
  end
end
