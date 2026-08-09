# frozen_string_literal: true

require "spec_helper"

# shadcn's `direction.tsx` wraps Radix's `DirectionProvider`, which renders no
# DOM: it is a React context, and it exists because a component cannot easily
# read inherited DOM state while rendering. A Stimulus controller can — the
# browser has resolved `dir` for every element before one runs.
#
# So the port is `shadcn/direction.js` and no component at all, and *this* is
# where that claim is worth anything: setting `dir` on an ancestor has to change
# what the arrow keys do, with nothing else wired up.
RSpec.describe "Reading direction", :js do
  def set_direction(value)
    page.execute_script("document.documentElement.setAttribute('dir', #{value.to_json})")
  end

  # Radix swaps the two horizontal arrows and nothing else
  # (`getDirectionAwareKey`, vendor/radix/ui/roving-focus-group.tsx:359): a
  # column is a column in either direction.
  describe "the tabs' roving focus" do
    let(:triggers) { "[data-slot=tabs-trigger]" }

    before do
      visit_preview(:tabs)
      wait_for_stimulus
      all(triggers).first.click
    end

    it "moves forward on ArrowRight while the page reads left to right" do
      first, second = all(triggers).first(2).map { |t| t["id"] }

      find("##{first}").send_keys(:arrow_right)

      expect(page.evaluate_script("document.activeElement.id")).to eq(second)
    end

    it "moves forward on ArrowLeft once the page reads right to left" do
      set_direction("rtl")
      first, second = all(triggers).first(2).map { |t| t["id"] }

      find("##{first}").send_keys(:arrow_left)

      expect(page.evaluate_script("document.activeElement.id")).to eq(second)
    end

    # The half that catches a swap applied in the wrong place: in RTL the key
    # labelled Right has to go *backwards*, not stay put.
    it "moves backward on ArrowRight once the page reads right to left" do
      set_direction("rtl")
      ids = all(triggers).first(2).map { |t| t["id"] }

      find("##{ids[1]}").click
      find("##{ids[1]}").send_keys(:arrow_right)

      expect(page.evaluate_script("document.activeElement.id")).to eq(ids[0])
    end
  end

  # Same module, a different controller, and a different shape of map — the
  # toggle group translates the key into a step rather than comparing it.
  describe "the toggle group" do
    let(:items) { "[data-slot=toggle-group-item]" }

    before do
      visit_preview(:toggle_group)
      wait_for_stimulus
      set_direction("rtl")
    end

    it "steps forward on ArrowLeft" do
      first, second = all(items).first(2)
      first.click

      first.send_keys(:arrow_left)

      expect(page.evaluate_script("document.activeElement.textContent.trim()"))
        .to eq(second.text.strip)
    end

    # The other half of Radix's rule, and the half a swap applied too broadly
    # gets wrong: a column is a column in either direction, so `ArrowUp` still
    # steps *backward* in RTL. Asserted here rather than on the tabs, where a
    # horizontal list ignores the vertical arrows outright and the assertion
    # would hold however they were translated.
    it "leaves the vertical arrows alone" do
      items_on_page = all(items)
      second = items_on_page[1]
      second.click

      second.send_keys(:arrow_up)

      expect(page.evaluate_script("document.activeElement.textContent.trim()"))
        .to eq(items_on_page[0].text.strip)
    end
  end
end
