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

    it "narrows the match as more characters arrive" do
      press("b")
      press("l")

      highlighted = page.evaluate_script(
        "document.querySelector('[data-slot=select-item][data-highlighted]')?.dataset.value"
      )

      expect(highlighted).to eq("blueberry")
    end

    # Radix's findNextItem collapses a repeated character to one and excludes
    # the currently highlighted item from the search (vendor/radix/ui/select.tsx:1906-1921),
    # so holding a letter cycles through every item starting with it rather than
    # staying on the first match.
    it "cycles to the next match when a character repeats" do
      press("b")
      press("b")

      highlighted = page.evaluate_script(
        "document.querySelector('[data-slot=select-item][data-highlighted]')?.dataset.value"
      )

      expect(highlighted).to eq("blueberry")
    end

    # Radix compares the raw characters to decide whether they repeat
    # (vendor/radix/ui/select.tsx:1911) and only lowercases for the match
    # itself (:1918) — "Bb" is not a repeat of "b", so it searches for the
    # literal two-character string, finds nothing, and does not move.
    it "does not treat a shifted letter as a repeat of the same letter" do
      press("B")
      press("b")

      highlighted = page.evaluate_script(
        "document.querySelector('[data-slot=select-item][data-highlighted]')?.dataset.value"
      )

      expect(highlighted).to eq("banana")
    end

    # Radix has no wrap-around at either end of the listbox
    # (vendor/radix/ui/select.tsx:904). These two guard both ends.
    it "does not move past the first item with ArrowUp" do
      press(:arrow_up)

      highlighted = page.evaluate_script(
        "document.querySelector('[data-slot=select-item][data-highlighted]')?.dataset.value"
      )

      expect(highlighted).to eq("apple")
    end

    it "does not move past the last item with ArrowDown" do
      5.times { press(:arrow_down) }

      highlighted = page.evaluate_script(
        "document.querySelector('[data-slot=select-item][data-highlighted]')?.dataset.value"
      )

      expect(highlighted).to eq("pineapple")
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

  # `onOpen` always highlights, so nothing a user can do reaches the listbox
  # with the cursor unset — with one exception: `selectedItem` searches every
  # item and `enabledItems` filters, so a selection that is also *disabled* is
  # highlighted on open and then not found among the candidates. Radix reverses
  # the candidates for ArrowUp and slices from an index of -1, which takes
  # nothing off (vendor/radix/ui/select.tsx:898-904), so focus enters at the
  # end.
  #
  # No preview renders that combination, and the state is set here directly
  # rather than by adding one — a preview is also a snapshot and an
  # accessibility fixture, and this is the same move
  # spec/system/typeahead_spec.rb makes for behaviour no preview reaches.
  context "when the selected item is disabled" do
    before do
      page.execute_script(<<~JS)
        const root = [...document.querySelectorAll("[data-slot=select]")].pop();
        root.querySelector("[data-slot=select-item][data-value=apple]").dataset.disabled = "";
        root.setAttribute("data-shadcn--select-value-value", "apple");
      JS
      open_select
    end

    it "highlights the selection even though it is not a candidate" do
      highlighted = page.evaluate_script(
        "document.querySelector('[data-slot=select-item][data-highlighted]')?.dataset.value"
      )

      expect(highlighted).to eq("apple")
    end

    it "enters at the last item on ArrowUp, rather than the first candidate" do
      press(:arrow_up)

      highlighted = page.evaluate_script(
        "document.querySelector('[data-slot=select-item][data-highlighted]')?.dataset.value"
      )

      expect(highlighted).to eq("pineapple")
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
