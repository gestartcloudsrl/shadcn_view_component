# frozen_string_literal: true

require "spec_helper"

# The behaviour, driven from the preview. `scroll_geometry_spec.rb` covers the
# measurements underneath; this covers what the controller does with them.
#
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

  # Where a given row sits relative to the viewport — the frame of reference the
  # whole prepend trick is built on, because it is the one that survives rows
  # being inserted above it.
  def viewport_top_of(message_id)
    page.evaluate_script(<<~JS)
      (() => {
        const item = document.querySelector('[data-message-id="#{message_id}"]')
        const viewport = document.querySelector("#{viewport}")
        return Math.round(item.getBoundingClientRect().top - viewport.getBoundingClientRect().top)
      })()
    JS
  end

  def prepend_messages(count)
    page.execute_script(<<~JS)
      const content = document.querySelector("[data-slot=message-scroller-content]")
      for (let i = 0; i < #{count}; i++) {
        const item = document.createElement("div")
        item.dataset.slot = "message-scroller-item"
        item.dataset.messageId = `older-${i}`
        item.dataset.scrollAnchor = "false"
        item.style.height = "150px"
        item.textContent = `older ${i}`
        content.insertBefore(item, content.firstElementChild)
      }
    JS
  end

  def append_anchor(id)
    page.execute_script(<<~JS)
      const content = document.querySelector("[data-slot=message-scroller-content]")
      const spacer = content.querySelector("[data-message-scroller-spacer]")
      const item = document.createElement("div")
      item.dataset.slot = "message-scroller-item"
      item.dataset.messageId = #{id.to_json}
      item.dataset.scrollAnchor = "true"
      item.style.height = "120px"
      item.textContent = "a new turn"
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

  # The behaviour a chat log is judged on. Loading older history inserts rows
  # *above* the viewport, and a scroller that treats them as content growth
  # throws the reader down the page.
  #
  # `overflow-anchor: none` is what makes this example mean anything. Chrome
  # anchors scroll natively and holds the position on its own, so the first
  # version of this passed with the whole prepend branch deleted — it was
  # measuring the browser. The controller exists for the engines that do not do
  # it (upstream names Safari), and its restore is deliberately written as a
  # correction that is a no-op where the browser got there first. Turning the
  # native behaviour off is how you ask whether *this* code works.
  it "holds the reader in place when older messages load above" do
    find(start_button).click
    wait_for_scroll_top(0)

    page.execute_script(
      "document.querySelector('[data-slot=message-scroller-content]').style.overflowAnchor = 'none'"
    )

    before_top = viewport_top_of("m1")
    prepend_messages(3)

    expect(viewport_top_of("m1")).to be_within(2).of(before_top)
    expect(scroll_top).to be >= 450
  end

  # An arriving turn is taken to the *top*, not the bottom — with the previous
  # one still peeking above it, which is what makes it read as a continuation
  # rather than as the start of the world.
  it "takes an arriving anchored turn to the top, leaving the previous one peeking" do
    find(start_button).click
    wait_for_scroll_top(0)

    append_anchor("turn-1")

    expect(page).to have_css('[data-message-id="turn-1"]')
    top = viewport_top_of("turn-1")
    expect(top).to be > 0
    expect(top).to be_within(24).of(64)
  end

  it "returns to the end from the end button" do
    find(start_button).click
    expect(page).to have_css("#{end_button}[data-active=true]")

    find(end_button).click

    expect(page).to have_css("#{end_button}[data-active=false]", visible: :all)
    expect(scroll_top).to be > 0
  end

  # Server rendering forces the one difference from upstream that is not a
  # translation. React mounts this component empty and fills it, so its first
  # content change takes the "no items before" branch, goes to the end, and
  # never jumps to an anchor that was there from the start — measured on the
  # live demo, where the tail spacer is hidden and the viewport sits at the end.
  #
  # Here the rows arrive with the document, so without seeding them as handled
  # the first observer finds an unhandled anchor and takes the reader to it: the
  # conversation opens part-way up, under a screenful of tail spacer.
  #
  # `/chat` is the fixture because it is the realistic case — the newest turn
  # marked, the way an application would render it.
  context "when the markup arrives with a turn already anchored" do
    before do
      visit "/chat"
      wait_for_stimulus
    end

    it "still opens at the live end, with no tail spacer" do
      state = page.evaluate_script(<<~JS)
        (() => {
          const viewport = document.querySelector("[data-slot=message-scroller-viewport]")
          const spacer = document.querySelector("[data-message-scroller-spacer]")
          const items = document.querySelectorAll("[data-slot=message-scroller-item]")
          const last = items[items.length - 1]
          return JSON.stringify({
            atEnd: Math.abs(viewport.scrollTop - (viewport.scrollHeight - viewport.clientHeight)) <= 1,
            spacerHidden: spacer.hidden,
            lastIsAnchor: last.dataset.scrollAnchor,
            lastBottomWithin: viewport.clientHeight -
              (last.getBoundingClientRect().bottom - viewport.getBoundingClientRect().top)
          })
        })()
      JS

      expect(JSON.parse(state)).to include(
        "atEnd" => true, "spacerHidden" => true, "lastIsAnchor" => "true"
      )
      # The newest message sits at the bottom of the frame, not somewhere up it.
      expect(JSON.parse(state)["lastBottomWithin"]).to be_between(0, 32)
    end
  end
end
