# frozen_string_literal: true

require "spec_helper"

RSpec.describe "DropdownMenu", :js do
  let(:content) { "[data-slot=dropdown-menu-content]" }
  let(:trigger) { "[data-slot=dropdown-menu-trigger]" }

  # The gallery header carries a ModeToggle, which is also a DropdownMenu, so
  # every lookup is scoped to the preview's own — the last one on the page.
  def preview
    all("[data-slot=dropdown-menu]").last
  end

  def open_menu
    within(preview) { find(trigger).click }
    expect(page).to have_css(content)
  end

  def highlighted
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll("[data-slot=dropdown-menu]")].pop()
        .querySelector("[data-slot=dropdown-menu-item][data-highlighted]")?.textContent.trim()
    JS
  end

  before do
    visit_preview(:dropdown_menu)
    wait_for_stimulus
  end

  it "starts closed with a menu-haspopup trigger" do
    within(preview) do
      expect(find(trigger)["aria-haspopup"]).to eq("menu")
      expect(find(trigger)["aria-expanded"]).to eq("false")
      expect(page).to have_no_css(content)
    end
  end

  context "when opened by click" do
    before { open_menu }

    it "exposes a menu and marks the trigger expanded" do
      within(preview) do
        expect(find(content)["role"]).to eq("menu")
        expect(find(trigger)["aria-expanded"]).to eq("true")
        expect(page).to have_css("[data-slot=dropdown-menu-item]", text: "Profile")
      end
    end

    it "jumps to an item by typing" do
      press("b")

      expect(highlighted).to eq("Billing")
    end

    it "highlights on hover" do
      find("[data-slot=dropdown-menu-item]", text: "Settings").hover

      expect(highlighted).to eq("Settings")
    end

    it "closes when an item is chosen, and returns focus to the trigger" do
      find("[data-slot=dropdown-menu-item]", text: "Billing").click

      expect(page).to have_no_css(content)
      expect(page.evaluate_script("document.activeElement.dataset.slot")).to eq("dropdown-menu-trigger")
    end

    it "closes on Escape" do
      press(:escape)

      expect(page).to have_no_css(content)
    end

    it "closes when clicking outside" do
      click_outside

      expect(page).to have_no_css(content)
    end
  end

  context "when opened with ArrowDown" do
    before { within(preview) { find(trigger).send_keys(:arrow_down) } }

    it "highlights the first item" do
      expect(page).to have_css(content)
      expect(highlighted).to start_with("Profile")
    end

    it "moves the highlight with the arrow keys, wrapping around" do
      press(:arrow_down)
      expect(highlighted).to eq("Billing")

      press(:arrow_up)
      expect(highlighted).to start_with("Profile")

      press(:arrow_up)
      expect(highlighted).to eq("Log out")
    end
  end

  context "when opened with ArrowUp" do
    it "highlights the last item" do
      within(preview) { find(trigger).send_keys(:arrow_up) }

      expect(page).to have_css(content)
      expect(highlighted).to eq("Log out")
    end
  end
end
