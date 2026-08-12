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

  # Where the scroller is, and where each slide sits in it — measured from the
  # first slide, not from the scroller's own zero. The track carries a negative
  # margin against the items' padding, so the first slide begins a gutter left
  # of zero and every reachable position is that far along from it.
  def geometry
    page.evaluate_script(<<~JS)
      (() => {
        const v = document.querySelector(#{viewport.to_json})
        const box = v.getBoundingClientRect()
        const positions = [...v.querySelectorAll("[data-slot=carousel-item]")]
          .map((i) => i.getBoundingClientRect().left - box.left + v.scrollLeft)
        const first = positions[0] || 0
        return {
          at: Math.round(v.scrollLeft),
          down: Math.round(v.scrollTop),
          max: Math.round(v.scrollWidth - v.clientWidth),
          offsets: positions.map((p) => Math.round(p - first))
        }
      })()
    JS
  end

  # Whether what a slide holds is wholly inside the window, which is the thing a
  # person sees. Reported as "the right border disappears": a card whose edge
  # falls a pixel outside a hidden overflow loses its border and nothing else,
  # so nothing that reads attributes can tell.
  def visible_slide_content
    page.evaluate_script(<<~JS)
      (() => {
        const v = document.querySelector(#{viewport.to_json})
        const box = v.getBoundingClientRect()
        return [...v.querySelectorAll("[data-slot=carousel-item] > *")]
          .map((c) => {
            const r = c.getBoundingClientRect()
            return { left: Math.round(r.left - box.left), right: Math.round(r.right - box.left) }
          })
          .filter((r) => r.right > 0 && r.left < Math.round(box.width))
          .map((r) => r.left >= -0.5 && r.right <= Math.round(box.width) + 0.5)
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

  # Reported from the gallery: past the first slide the card lost its right
  # border, and in a carousel with a smaller gutter the first one lost its left.
  #
  # A slide is a gutter wider than the window it has to fit in — the track's
  # negative margin against the item's padding — so aligning an item's *box*
  # with the window's edge pushes a gutter's worth of its *content* off the far
  # side. One border's worth of it, which no attribute records.
  it "shows every slide whole, border and all", :aggregate_failures do
    expect(visible_slide_content).to all(be(true))

    (geometry["offsets"].size - 1).times do |i|
      find(nxt).click
      expect(resting_position).to eq(geometry["offsets"][i + 1])
      expect(visible_slide_content).to all(be(true))
    end
  end

  # What a released drag does, which is the whole reason the viewport is a
  # scroller rather than a translated track: let go between two slides and the
  # browser finishes the journey. It has to finish it in the same place the
  # buttons would, or dragging and clicking disagree by a gutter — which is what
  # the items' negative `scroll-margin` is for.
  it "settles on a slide when left between two" do
    offsets = geometry["offsets"]
    between = offsets[1] + ((offsets[2] - offsets[1]) / 3)

    page.execute_script("document.querySelector(#{viewport.to_json}).scrollLeft = #{between}")

    # On *a* slide — which one is the browser's business, and at a third of the
    # way it will say the one behind. What matters is that the set it chooses
    # from is the same set the buttons use: without the items' negative
    # `scroll-margin` the browser snaps to their boxes, a gutter away from every
    # one of these, and dragging and clicking stop agreeing.
    expect(offsets).to include(resting_position)
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
