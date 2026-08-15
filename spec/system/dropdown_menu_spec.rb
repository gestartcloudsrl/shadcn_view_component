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

    # The dropdown menu's own upstream, Radix's getNextMatch
    # (vendor/radix/ui/menu.tsx:1336-1347), has the same body as select's
    # findNextItem (vendor/radix/ui/select.tsx:1906-1921) that Typeahead#search
    # ports: both collapse a repeated character to one and exclude the
    # currently highlighted item from the search, so holding a letter cycles
    # through every item starting with it rather than staying on the first
    # match.
    it "cycles to the next match when a character repeats" do
      press("s")
      press("s")

      expect(highlighted).to eq("Support")
    end

    # Two items with the same label are two destinations here and one in Radix's
    # *menu*, and that difference is deliberate — see the comment at the top of
    # `typeahead.js`. Radix hands `getNextMatch` an array of label *strings*
    # (menu.tsx:451-454), so with the second Copy highlighted `indexOf` finds
    # the first, the single-character filter drops both, and the highlight does
    # not move: the duplicate cannot be reached by typing at all. This port
    # compares elements, so it walks from one to the other.
    #
    # The labels are renamed here rather than in a preview: a gallery page with
    # two identical commands in it would be documentation of something nobody
    # should write, and what is being pinned is the algorithm, not the menu.
    it "walks between two items that share a label, where Radix's menu cannot" do
      # Scoped to the preview's own menu, as `highlighted` is: the gallery
      # layout carries a ModeToggle and a ThemeSelector, so an unscoped lookup
      # renames somebody else's items — which is exactly what it did first.
      renamed = page.evaluate_script(<<~JS)
        (() => {
          const menu = [...document.querySelectorAll("[data-slot=dropdown-menu]")].pop()
          const items = [...menu.querySelectorAll("[data-slot=dropdown-menu-item]")]
          // Replaced wholesale rather than by first child: the first item
          // carries a shortcut beside its label, and renaming only the label
          // left "Copy⌘P" — which starts with the same letter and would have
          // passed the assertions below while measuring something else.
          items[0].textContent = "Copy"
          items[1].textContent = "Copy"
          return items.slice(0, 2).map((item) => item.textContent.trim())
        })()
      JS
      expect(renamed).to eq([ "Copy", "Copy" ])

      press("c")
      first = highlighted
      press("c")

      expect(first).to eq("Copy")
      expect(highlighted).to eq("Copy")
      expect(page.evaluate_script(<<~JS)).to eq(1)
        [...[...document.querySelectorAll("[data-slot=dropdown-menu]")].pop()
          .querySelectorAll("[data-slot=dropdown-menu-item]")]
          .findIndex((item) => item.dataset.highlighted !== undefined)
      JS
    end

    # Radix's menu drops the buffer when focus leaves the content
    # (vendor/radix/ui/menu.tsx:585-590), which for this gem is the moment the
    # layer closes and hands focus back to the trigger.
    #
    # Without it, "s" and then "b" across a close search "sb", match nothing and
    # leave the highlight empty. The buffer's own one-second expiry would cover
    # that up and make this a race against how fast Capybara can reopen the
    # menu, so the 1s timeout `typeahead.js:32` schedules is disabled for the
    # duration — leaving the reset as the only thing that can empty the buffer.
    it "starts a fresh search after closing, rather than continuing the last one" do
      page.execute_script(<<~JS)
        window.realSetTimeout ||= window.setTimeout
        window.setTimeout = (fn, delay, ...rest) =>
          delay === 1000 ? 0 : window.realSetTimeout(fn, delay, ...rest)
      JS

      press("s")
      expect(highlighted).to eq("Settings")

      press(:escape)
      expect(page).to have_no_css(content)
      open_menu

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

    # A click leaves the cursor unset, so this is the one entry into the menu
    # where ArrowUp has no previous item to step back from. Radix lists ArrowUp
    # in `LAST_KEYS` and reverses the candidates before `focusFirst`
    # (vendor/radix/ui/menu.tsx:576-583), which lands on the last item — the
    # clamp cases below all press ArrowDown first and so never reach it.
    it "enters at the last item when ArrowUp is the first key pressed" do
      press(:arrow_up)

      expect(highlighted).to eq("Log out")
    end
  end

  context "when opened with ArrowDown" do
    before { within(preview) { find(trigger).send_keys(:arrow_down) } }

    it "highlights the first item" do
      expect(page).to have_css(content)
      expect(highlighted).to start_with("Profile")
    end

    it "moves the highlight with the arrow keys, clamping at the first item" do
      press(:arrow_down)
      expect(highlighted).to eq("Billing")

      press(:arrow_up)
      expect(highlighted).to start_with("Profile")

      press(:arrow_up)
      expect(highlighted).to start_with("Profile")
    end

    # Radix wraps at neither end *unless asked to*: `loop` defaults to false
    # (vendor/radix/ui/menu.tsx:387) and decides the branch at
    # vendor/radix/ui/roving-focus-group.tsx:324-326. The counterpart above
    # guards the top; this guards the bottom. `with loop enabled` below is the
    # other half of the same flag.
    it "does not move past the last item with ArrowDown" do
      4.times { press(:arrow_down) }

      expect(highlighted).to eq("Log out")
    end
  end

  # The preview does not pass `loop`, so the flag is set on the element rather
  # than through a second preview: Stimulus reads a value off its attribute, so
  # a menu opened after the attribute lands sees it. Nothing else about the
  # preview changes, which is what makes this the same menu as the context
  # above rather than a lookalike.
  context "with loop enabled" do
    before do
      page.execute_script(<<~JS)
        [...document.querySelectorAll("[data-slot=dropdown-menu]")].pop()
          .setAttribute("data-shadcn--dropdown-menu-loop-value", "true")
      JS
      within(preview) { find(trigger).send_keys(:arrow_down) }
    end

    it "wraps past the last item back to the first" do
      4.times { press(:arrow_down) }
      expect(highlighted).to eq("Log out")

      press(:arrow_down)
      expect(highlighted).to start_with("Profile")
    end

    it "wraps past the first item back to the last" do
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
