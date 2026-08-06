# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Select", :js do
  let(:trigger) { "[data-slot=select-trigger]" }
  let(:content) { "[data-slot=select-content]" }

  # The gallery header carries a ThemeSelector, which is also a Select. Scope
  # every lookup to the preview's own.
  def preview
    all("[data-slot=select]").last
  end

  def open_select
    within(preview) { find(trigger).click }
    expect(page).to have_css(content)
  end

  def value
    within(preview) { find("input[name=fruit]", visible: :all).value }
  end

  before do
    visit_preview(:select)
    wait_for_stimulus
  end

  it "starts closed, with the trigger a combobox showing the placeholder" do
    within(preview) do
      expect(find(trigger)["role"]).to eq("combobox")
      expect(find(trigger)["aria-expanded"]).to eq("false")
      expect(find(trigger)).to have_text("Select a fruit")
      expect(page).to have_no_css(content)
    end
  end

  # `crypto.randomUUID()` is secure-context only, so over plain HTTP it was
  # `undefined` and the controller threw on connect.
  it "uses sequential ids, so it works outside a secure context" do
    id = within(preview) { find(content, visible: :all)["id"] }

    expect(id).to match(/\Ashadcn-select-\d+\z/)
  end

  context "when opened" do
    before { open_select }

    it "marks the trigger expanded" do
      within(preview) { expect(find(trigger)["aria-expanded"]).to eq("true") }
    end

    it "positions itself under the trigger", :aggregate_failures do
      boxes = page.evaluate_script(<<~JS)
        (() => {
          const root = [...document.querySelectorAll("[data-slot=select]")].pop();
          const t = root.querySelector("[data-slot=select-trigger]").getBoundingClientRect();
          const c = root.querySelector("[data-slot=select-content]").getBoundingClientRect();
          return { below: c.top >= t.bottom - 1, aligned: Math.abs(c.left - t.left) < 40, width: c.width };
        })()
      JS

      expect(boxes["below"]).to be(true)
      expect(boxes["aligned"]).to be(true)
      expect(boxes["width"]).to be > 0
    end

    it "selects with the mouse and mirrors the value into the hidden input" do
      find("[data-slot=select-item][data-value=blueberry]").click

      within(preview) do
        expect(find("[data-slot=select-value]")).to have_text("Blueberry")
        expect(find(trigger)["aria-expanded"]).to eq("false")
        expect(find("[data-slot=select-item][data-value=blueberry]", visible: :all)["data-state"])
          .to eq("checked")
      end
      expect(value).to eq("blueberry")
    end

    it "navigates with the arrow keys and picks with Enter" do
      press(:arrow_down)
      press(:arrow_down)
      press(:enter)

      expect(value).to eq("blueberry")
    end

    it "jumps to an option by typing" do
      press("g")

      highlighted = page.evaluate_script(
        "document.querySelector('[data-slot=select-item][data-highlighted]')?.dataset.value"
      )

      expect(highlighted).to eq("grapes")
    end

    it "closes on Escape without changing the value" do
      press(:escape)

      expect(page).to have_no_css(content)
      expect(value).to eq("")
    end

    it "closes when clicking outside" do
      click_outside

      expect(page).to have_no_css(content)
    end
  end

  # The content is moved into a positioned wrapper while open. It used to come
  # back at the end of its container, which permanently reordered the markup.
  context "when opened and closed repeatedly" do
    it "puts the content back where it was" do
      order = lambda do
        page.evaluate_script(<<~JS)
          [...[...document.querySelectorAll("[data-slot=select]")].pop().children]
            .map(c => c.dataset.slot || c.tagName.toLowerCase())
        JS
      end
      original = order.call

      3.times do
        open_select
        press(:escape)
        expect(page).to have_no_css(content)
      end

      expect(order.call).to eq(original)
    end
  end
end
