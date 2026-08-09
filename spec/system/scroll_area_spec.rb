# frozen_string_literal: true

require "spec_helper"

# The component is two numbers per axis: how long the thumb is, and how far
# along it sits. Everything else — where the bar goes, how thick it is, where it
# stops — is CSS, which is why 1,189 lines of Radix come down to a controller
# that writes a custom property and a transform.
#
# So these assert the numbers rather than appearances. A thumb whose length does
# not track the content is the failure this component exists to avoid, and it is
# invisible to every other spec here.
RSpec.describe "Scroll area", :js do
  let(:area) { "[data-slot=scroll-area]" }
  let(:viewport) { "[data-slot=scroll-area-viewport]" }
  let(:vertical_bar) { "[data-slot=scroll-area-scrollbar][data-orientation=vertical]" }

  # The first area in the preview: vertical only, `type: :hover`.
  def first_area = all(area).first

  def thumb_metrics(bar_selector = vertical_bar)
    page.evaluate_script(<<~JS)
      (() => {
        const bar = document.querySelector(#{bar_selector.to_json})
        const thumb = bar.querySelector("[data-slot=scroll-area-thumb]")
        const rect = thumb.getBoundingClientRect()
        const barRect = bar.getBoundingClientRect()
        return {
          state: bar.dataset.state,
          length: Math.round(rect.height),
          offset: Math.round(rect.top - barRect.top),
          track: Math.round(barRect.height)
        }
      })()
    JS
  end

  before do
    visit_preview(:scroll_area)
    wait_for_stimulus
  end

  # Radix's `type="hover"` does not render the bar at all until the pointer
  # arrives. Nothing is unmounted here — the same rule that keeps floating
  # content in place — so the state attribute carries what a missing element
  # carried there.
  # Scoped to the first area throughout. The second one is `type: :always`, so
  # an unscoped `have_css(...[data-state=visible])` matches *its* bar and passes
  # however this area behaves — which it did, until a mutation that stopped
  # hover working entirely failed nothing.
  it "keeps the bar hidden until the pointer arrives, and puts it back after" do
    expect(first_area).to have_css("#{vertical_bar}[data-state=hidden]", visible: :all)

    first_area.hover
    expect(first_area).to have_css("#{vertical_bar}[data-state=visible]", visible: :all)

    # Away again. The bar goes after `scroll_hide_delay`, 600ms by default —
    # inside Capybara's wait, so the matcher does the waiting.
    find("body").hover
    expect(first_area).to have_css("#{vertical_bar}[data-state=hidden]", visible: :all)
  end

  # The number the whole component is for: the thumb is as long a fraction of
  # the track as the viewport is of the content. The preview's first area shows
  # a little under a third of its rows, so a thumb the length of the track means
  # the geometry was never read.
  it "sizes the thumb to the fraction of the content on screen" do
    metrics = thumb_metrics
    ratio = page.evaluate_script(<<~JS)
      (() => {
        const v = document.querySelector(#{viewport.to_json})
        return v.clientHeight / v.scrollHeight
      })()
    JS

    expect(metrics["length"]).to be_within(4).of((metrics["track"] * ratio).round)
    expect(metrics["length"]).to be < metrics["track"] / 2
  end

  it "moves the thumb as the viewport scrolls, and lands it at the end" do
    at_rest = thumb_metrics
    # Not exactly zero: the bar carries `p-px`, so the track starts a pixel in.
    expect(at_rest["offset"]).to be_within(2).of(0)

    page.execute_script(<<~JS)
      const v = document.querySelector(#{viewport.to_json})
      v.scrollTop = v.scrollHeight - v.clientHeight
      v.dispatchEvent(new Event("scroll"))
    JS

    scrolled = thumb_metrics
    expect(scrolled["offset"]).to be > at_rest["offset"]
    # At the end of the content the thumb is at the end of its track, give or
    # take the bar's own padding.
    expect(scrolled["offset"] + scrolled["length"]).to be_within(4).of(scrolled["track"])
  end

  # Pressing the track jumps there rather than paging, which is what Radix's
  # `getScrollPositionFromPointer` does with a press outside the thumb.
  it "scrolls to where the track is pressed" do
    first_area.hover
    expect(first_area).to have_css("#{vertical_bar}[data-state=visible]", visible: :all)

    # Scoped to the first area: the second one has a vertical bar too, and an
    # unscoped lookup matches both.
    bar = first_area.find(vertical_bar, visible: :all)
    bar.click(x: 0, y: 40)

    expect(page.evaluate_script("document.querySelector(#{viewport.to_json}).scrollTop")).to be > 0
  end

  describe "the area that asks for both axes" do
    let(:both) { all(area).last }

    it "shows both bars at once with type always, and neither waits for a pointer" do
      within_area = ->(selector) { both.find(selector, visible: :all) }

      expect(within_area.call("[data-orientation=vertical]")["data-state"]).to eq("visible")
      expect(within_area.call("[data-orientation=horizontal]")["data-state"]).to eq("visible")
    end

    # Each bar stops short of the other by its thickness, and the corner fills
    # what is left — published as the custom properties the bars' inline
    # `bottom` and `right` already read.
    it "keeps the two bars out of each other's corner" do
      corner = page.evaluate_script(<<~JS)
        (() => {
          const root = arguments === undefined ? null : null
          const areas = document.querySelectorAll("[data-slot=scroll-area]")
          const el = areas[areas.length - 1]
          const style = window.getComputedStyle(el)
          return {
            width: style.getPropertyValue("--radix-scroll-area-corner-width").trim(),
            height: style.getPropertyValue("--radix-scroll-area-corner-height").trim()
          }
        })()
      JS

      expect(corner["width"]).not_to eq("")
      expect(corner["width"]).not_to eq("0px")
      expect(corner["height"]).not_to eq("0px")
    end
  end
end
