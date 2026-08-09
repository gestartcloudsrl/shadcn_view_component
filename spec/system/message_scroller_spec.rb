# frozen_string_literal: true

require "spec_helper"

# The behaviour, driven from the preview. `scroll_geometry_spec.rb` covers the
# measurements underneath; this covers what the controller does with them.
#
# Prepend anchoring is not here because it is not written yet — the rows carry
# `data-scroll-anchor` for the geometry to read and nothing acts on it. See
# `.claude/docs/features/message-scroller.md`.
RSpec.describe "Message scroller", :js do
  let(:root) { "[data-slot=message-scroller]" }
  let(:viewport) { "[data-slot=message-scroller-viewport]" }
  let(:end_button) { "[data-slot=message-scroller-button][data-direction=end]" }
  let(:start_button) { "[data-slot=message-scroller-button][data-direction=start]" }

  def scroll_top
    page.evaluate_script("document.querySelector('#{viewport}').scrollTop")
  end

  # The buttons scroll smoothly, so a position read straight after a click is
  # reading the animation rather than the result. Retried, the way every other
  # geometry assertion in this suite is.
  def wait_for_scroll_top(expected)
    page.document.synchronize do
      actual = scroll_top
      next if (actual - expected).abs <= 1

      raise Capybara::ExpectationNotMet, "scrollTop settled at #{actual}, not #{expected}"
    end
  end

  def append_message(text)
    page.execute_script(<<~JS)
      const content = document.querySelector("[data-slot=message-scroller-content]")
      const spacer = content.querySelector("[data-message-scroller-spacer]")
      const item = document.createElement("div")
      item.dataset.slot = "message-scroller-item"
      item.dataset.messageId = "appended-#{text}"
      item.dataset.scrollAnchor = "false"
      item.style.height = "120px"
      item.textContent = #{text.to_json}
      content.insertBefore(item, spacer)
    JS
  end

  before do
    visit_preview(:message_scroller)
    wait_for_stimulus
  end

  # `defaultScrollPosition` is `end`, so the newest message is what you see
  # first — the whole point of the component, and the thing a plain
  # `overflow-y: auto` does not do.
  it "opens at the live end" do
    expect(page).to have_css("#{root}[data-scrollable~=start]")
    expect(scroll_top).to be > 0
  end

  # `data-scrollable` is published on the root *and* the viewport, and it is
  # what the buttons read. While following, the end is deliberately not
  # published — see the controller — so only the start button is lit.
  #
  # `visible: :all` on the inactive one: `data-[active=false]` translates it a
  # full height out of a root that is `overflow-hidden`, so the driver reports
  # it as not displayed. What is being asserted is the attribute the controller
  # writes, not whether it can be seen — and being out of sight is the point.
  it "lights the start button and not the end one while it is following" do
    expect(page).to have_css("#{start_button}[data-active=true]")
    expect(page).to have_css("#{end_button}[data-active=false]", visible: :all)
  end

  it "scrolls back to the top from the start button, and lights the other one" do
    find(start_button).click

    expect(page).to have_css("#{end_button}[data-active=true]")
    expect(page).to have_css("#{start_button}[data-active=false]", visible: :all)
    wait_for_scroll_top(0)
  end

  # The behaviour the component exists for: a message arriving while the reader
  # is at the live end brings the view with it.
  it "follows the live end when a message arrives" do
    before_append = scroll_top
    append_message("a new message")

    expect(page).to have_css("#{root}[data-scrollable~=start]")
    expect(scroll_top).to be > before_append
  end

  # And the half that is easy to get wrong: having scrolled up to read, the
  # reader must not be yanked back down. Only scrolling *up* releases
  # following — content growing also reads as "not at the end", and treating
  # that as a release would drop the mode on the first streamed chunk.
  it "stays put when a message arrives after the reader has scrolled away" do
    find(start_button).click
    expect(page).to have_css("#{end_button}[data-active=true]")

    append_message("another message")

    expect(page).to have_css("#{end_button}[data-active=true]")
    wait_for_scroll_top(0)
  end

  it "returns to the end from the end button" do
    find(start_button).click
    expect(page).to have_css("#{end_button}[data-active=true]")

    find(end_button).click

    expect(page).to have_css("#{end_button}[data-active=false]", visible: :all)
    expect(scroll_top).to be > 0
  end
end
