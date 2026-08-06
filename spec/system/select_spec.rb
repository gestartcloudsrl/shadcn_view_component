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

  it "opens on click and positions itself under the trigger" do
    within(preview) { find(trigger).click }

    expect(page).to have_css(content)
    within(preview) { expect(find(trigger)["aria-expanded"]).to eq("true") }

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
    within(preview) { find(trigger).click }
    find("[data-slot=select-item][data-value=blueberry]").click

    within(preview) do
      expect(find("[data-slot=select-value]")).to have_text("Blueberry")
      expect(find(trigger)["aria-expanded"]).to eq("false")
      expect(find("input[name=fruit]", visible: :all).value).to eq("blueberry")
      expect(find("[data-slot=select-item][data-value=blueberry]", visible: :all)["data-state"])
        .to eq("checked")
    end
  end

  it "navigates with the arrow keys and picks with Enter" do
    within(preview) { find(trigger).click }
    expect(page).to have_css(content)

    press(:arrow_down)
    press(:arrow_down)
    press(:enter)

    within(preview) { expect(find("input[name=fruit]", visible: :all).value).to eq("blueberry") }
  end

  it "jumps to an option by typing" do
    within(preview) { find(trigger).click }
    expect(page).to have_css(content)

    press("g")

    highlighted = page.evaluate_script(
      "document.querySelector('[data-slot=select-item][data-highlighted]')?.dataset.value"
    )
    expect(highlighted).to eq("grapes")
  end

  it "closes on Escape without changing the value" do
    within(preview) { find(trigger).click }
    press(:escape)

    within(preview) do
      expect(page).to have_no_css(content)
      expect(find("input[name=fruit]", visible: :all).value).to eq("")
    end
  end

  it "closes when clicking outside" do
    within(preview) { find(trigger).click }
    expect(page).to have_css(content)

    click_outside
    expect(page).to have_no_css(content)
  end

  # The content is moved into a positioned wrapper while open. It used to come
  # back at the end of its container, which permanently reordered the markup.
  it "puts the content back where it was after closing" do
    order = lambda do
      page.evaluate_script(<<~JS)
        [...[...document.querySelectorAll("[data-slot=select]")].pop().children]
          .map(c => c.dataset.slot || c.tagName.toLowerCase())
      JS
    end

    before = order.call

    3.times do
      within(preview) { find(trigger).click }
      expect(page).to have_css(content)
      press(:escape)
      expect(page).to have_no_css(content)
    end

    expect(order.call).to eq(before)
  end

  # `crypto.randomUUID()` is secure-context only, so over plain HTTP it was
  # `undefined` and the controller threw on connect.
  it "uses sequential ids, so it works outside a secure context" do
    id = within(preview) { find(content, visible: :all)["id"] }

    expect(id).to match(/\Ashadcn-select-\d+\z/)
  end
end
