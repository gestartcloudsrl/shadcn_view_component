# frozen_string_literal: true

require "spec_helper"

# The whole of what this component has to do, and the whole of what upstream
# asks embla for: move to the next slide, move to the previous one, and know
# when there is no next or previous to move to.
#
# Driven through the buttons rather than the controller, because "the button is
# disabled" is half the behaviour and a controller method cannot tell you
# whether a person could have reached it.
RSpec.describe "Carousel", :js do
  let(:viewport) { "[data-slot=carousel-content]" }
  let(:previous) { "[data-slot=carousel-previous]" }
  let(:nxt) { "[data-slot=carousel-next]" }

  # Where the scroller is, and where each slide sits in it. The track carries a
  # negative margin against the items' padding, so the first slide starts left
  # of zero and slide positions are not multiples of a width.
  def geometry
    page.evaluate_script(<<~JS)
      (() => {
        const v = document.querySelector(#{viewport.to_json})
        const box = v.getBoundingClientRect()
        return {
          at: Math.round(v.scrollLeft),
          down: Math.round(v.scrollTop),
          max: Math.round(v.scrollWidth - v.clientWidth),
          offsets: [...v.querySelectorAll("[data-slot=carousel-item]")]
            .map((i) => Math.round(i.getBoundingClientRect().left - box.left + v.scrollLeft))
        }
      })()
    JS
  end

  # Where the scroller comes to rest. A scroll settles a frame or two after the
  # click, and under `--force-prefers-reduced-motion` — which this suite runs
  # with — it settles at once, so this waits for two readings to agree rather
  # than for a duration. Returning the position lets each example say what it
  # expected instead of hiding the assertion in a retry.
  def resting_position(axis = "at")
    last = nil

    page.document.synchronize do
      at = geometry[axis]
      settled = at == last
      last = at
      raise Capybara::ExpectationNotMet, "still moving" unless settled

      at
    end
  end

  before do
    visit_preview(:carousel)
    wait_for_stimulus
  end

  it "starts at the first slide, with nowhere to go back to" do
    expect(geometry["at"]).to eq(0)
    expect(find(previous)).to be_disabled
    expect(find(nxt)).not_to be_disabled
  end

  it "moves to the next slide, and to the one after it" do
    second, third = geometry["offsets"].values_at(1, 2)

    find(nxt).click
    expect(resting_position).to eq(second)

    find(nxt).click
    expect(resting_position).to eq(third)
  end

  it "comes back the way it went" do
    second = geometry["offsets"][1]

    find(nxt).click
    expect(resting_position).to eq(second)

    find(previous).click
    expect(resting_position).to be_zero
    expect(find(previous)).to be_disabled
  end

  # The two `canScroll` questions, which upstream asks embla and this asks the
  # scroller. They are what makes the buttons say whether they will do anything.
  it "runs out of next at the end and out of previous at the start", :aggregate_failures do
    max = geometry["max"]

    page.execute_script("document.querySelector(#{viewport.to_json}).scrollLeft = #{max}")
    expect(page).to have_css("#{nxt}[disabled]")
    expect(find(previous)).not_to be_disabled

    page.execute_script("document.querySelector(#{viewport.to_json}).scrollLeft = 0")
    expect(page).to have_css("#{previous}[disabled]")
    expect(find(nxt)).not_to be_disabled
  end

  # Upstream binds these on the root and captures, so a control inside a slide
  # does not swallow them (carousel.tsx:119).
  it "moves with the arrow keys" do
    second = geometry["offsets"][1]

    # Pressed on the next button, which is where a keyboard reaches this
    # component: the root takes no focus of its own, upstream's does not either,
    # and the handler is on the capture phase so it sees keys from inside.
    find(nxt).send_keys(:arrow_right)
    expect(resting_position).to eq(second)

    find(nxt).send_keys(:arrow_left)
    expect(resting_position).to be_zero
  end

  # The viewport is a real scroll container, which is the whole mechanism: a
  # finger drags it, and a release lands on a slide rather than between two.
  # `overflow: hidden` alone would leave it scrollable by script and by nobody
  # else.
  it "is a scroller that snaps", :aggregate_failures do
    style = page.evaluate_script(<<~JS)
      (() => {
        const v = document.querySelector(#{viewport.to_json})
        const s = getComputedStyle(v)
        const item = v.querySelector("[data-slot=carousel-item]")
        return { overflowX: s.overflowX, snap: s.scrollSnapType,
                 align: getComputedStyle(item).scrollSnapAlign }
      })()
    JS

    expect(style["overflowX"]).to eq("auto")
    expect(style["snap"]).to eq("x mandatory")
    expect(style["align"]).to eq("start")
  end

  describe "when it is vertical" do
    before do
      visit_preview(:carousel, :vertical)
      wait_for_stimulus
    end

    it "scrolls down the other axis" do
      moved = page.evaluate_script(<<~JS)
        (() => {
          const v = document.querySelector(#{viewport.to_json})
          return { top: Math.round(v.scrollTop), max: Math.round(v.scrollHeight - v.clientHeight),
                   overflowY: getComputedStyle(v).overflowY }
        })()
      JS

      expect(moved["overflowY"]).to eq("auto")
      expect(moved["max"]).to be > 0

      find(nxt).click
      expect(resting_position("down")).to be_positive
    end
  end
end
