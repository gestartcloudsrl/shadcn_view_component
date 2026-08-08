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

  # A method rather than a `let`: every caller reads it after a keystroke has
  # moved the highlight, and a memoised value would answer with the state
  # before the key was pressed.
  def highlighted
    page.evaluate_script(
      "document.querySelector('[data-slot=select-item][data-highlighted]')?.dataset.value"
    )
  end

  # Both are methods rather than `let` for the reason above: each is read after
  # a keystroke has changed the DOM, and a memoised value would answer with the
  # state before it.
  def fill_in_search(query)
    within(preview) { find("[data-slot=select-input-wrapper] input").set(query) }
  end

  # Scoped to the preview's own select: the gallery's ThemeSelector is one too,
  # and its options would otherwise be counted among these.
  def visible_item_values
    page.evaluate_script(<<~JS)
      [...[...document.querySelectorAll("[data-slot=select]")].pop()
        .querySelectorAll("[data-slot=select-item]")]
        .filter((item) => !item.hidden)
        .map((item) => item.dataset.value)
    JS
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

      expect(highlighted).to eq("grapes")
    end

    it "narrows the match as more characters arrive" do
      press("b")
      press("l")

      expect(highlighted).to eq("blueberry")
    end

    # The counterpart to the example above: there, the second character narrows
    # to a real match; here it narrows to none. `findNextItem` returns
    # `undefined` and the caller leaves the highlight alone
    # (vendor/radix/ui/select.tsx:1920), so a mistyped second character parks
    # the search for the rest of the second rather than falling back to
    # matching on it alone. Waiting out the buffer and pressing "p" again does
    # reach pineapple — that half is the 1s timer in typeahead.js:32.
    it "stays put when the accumulated search matches nothing" do
      press("g")
      press("p")

      expect(highlighted).to eq("grapes")
    end

    # Radix resets the buffer when the panel opens — "reset typeahead when we
    # open" (vendor/radix/ui/select.tsx:331-336) — so a character typed before
    # the last dismissal cannot join the next search.
    #
    # The buffer also empties itself one second after the last keystroke, which
    # would hide a missing reset and turn this into a race against however long
    # Capybara takes to reopen the panel. Disabling exactly the 1s timeout that
    # `typeahead.js:32` schedules leaves the reset as the only thing that can
    # explain an empty buffer.
    it "starts a fresh search when reopened, rather than continuing the last one" do
      page.execute_script(<<~JS)
        window.realSetTimeout ||= window.setTimeout
        window.setTimeout = (fn, delay, ...rest) =>
          delay === 1000 ? 0 : window.realSetTimeout(fn, delay, ...rest)
      JS

      press("g")
      expect(highlighted).to eq("grapes")

      press(:escape)
      expect(page).to have_no_css(content)
      open_select

      press("p")

      expect(highlighted).to eq("pineapple")
    end

    # Radix's findNextItem collapses a repeated character to one and excludes
    # the currently highlighted item from the search (vendor/radix/ui/select.tsx:1906-1921),
    # so holding a letter cycles through every item starting with it rather than
    # staying on the first match.
    it "cycles to the next match when a character repeats" do
      press("b")
      press("b")

      expect(highlighted).to eq("blueberry")
    end

    # Radix compares the raw characters to decide whether they repeat
    # (vendor/radix/ui/select.tsx:1911) and only lowercases for the match
    # itself (:1918) — "Bb" is not a repeat of "b", so it searches for the
    # literal two-character string, finds nothing, and does not move.
    it "does not treat a shifted letter as a repeat of the same letter" do
      press("B")
      press("b")

      expect(highlighted).to eq("banana")
    end

    # Radix has no wrap-around at either end of the listbox
    # (vendor/radix/ui/select.tsx:904). These two guard both ends.
    it "does not move past the first item with ArrowUp" do
      press(:arrow_up)

      expect(highlighted).to eq("apple")
    end

    it "does not move past the last item with ArrowDown" do
      5.times { press(:arrow_down) }

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

  # The two chevrons were markup only: reproduced because shadcn emits them,
  # wired to nothing, so a list too long to fit showed a scroll affordance that
  # did not scroll. Radix mounts each one only while the viewport can scroll
  # that way (vendor/radix/ui/select.tsx:1585, :1630-1634) and auto-scrolls on
  # pointer (:1697-1706).
  #
  # The preview's five fruits fit, so the container is shrunk here rather than
  # by adding a preview whose only purpose is to overflow — a preview is also a
  # snapshot and an axe fixture, and this needs neither.
  # The two chevrons were markup only: reproduced because shadcn emits them,
  # wired to nothing, so a list too long to fit showed a scroll affordance that
  # did not scroll. Radix mounts each one only while the viewport can scroll
  # that way (vendor/radix/ui/select.tsx:1585, :1630-1634) and auto-scrolls on
  # pointer at 50ms intervals (:1697-1706).
  #
  # Driven from a preview that really overflows rather than by shrinking the
  # panel from JavaScript: the floating layer rewrites the inline style when it
  # positions, so a height set beforehand does not survive the open.
  context "when the options overflow" do
    before do
      visit_preview(:select, :scrollable)
      wait_for_stimulus
      open_select
    end

    def scroll_button(direction)
      within(preview) { find("[data-slot=select-scroll-#{direction}-button]", visible: :all) }
    end

    def scroll_top
      page.evaluate_script("[...document.querySelectorAll('[data-slot=select-content]')].pop().scrollTop")
    end

    it "offers to scroll down, but not up, at the top of the list" do
      expect(scroll_button("down")).to be_visible
      expect(scroll_button("up")).not_to be_visible
    end

    # Assigning scrollTop fires a real scroll event, which is the listener this
    # example is about.
    it "swaps them at the bottom" do
      page.execute_script(
        "const b = [...document.querySelectorAll('[data-slot=select-content]')].pop();" \
        "b.scrollTop = b.scrollHeight"
      )

      expect(scroll_button("up")).to be_visible
      expect(scroll_button("down")).not_to be_visible
    end

    # The auto-scroll itself has no example here, deliberately. Every way of
    # putting a pointer on the button from Capybara scrolls the panel as a side
    # effect — Selenium moves an element into view before pointing at it, and
    # this button is the last child of the element that scrolls — so the list
    # reaches its end whether or not the interval ever runs. Two attempts
    # passed with `startAutoScroll` neutralised, which is a spec that proves
    # nothing.
    #
    # Verified by hand instead, in a real browser: a `pointermove` on the down
    # button took scrollTop from 88 to 120 over 300ms. That is a weaker
    # guarantee than the rest of this file carries, and it is written down
    # rather than papered over. See todo.md.
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
      expect(highlighted).to eq("apple")
    end

    it "enters at the last item on ArrowUp, rather than the first candidate" do
      press(:arrow_up)

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

  # The searchable select is this gem's own component rather than a port — no
  # Radix base has one. What it takes from shadcn's React Aria variant is the
  # shape, and the shape is the thing worth asserting: a text field and a
  # listbox cannot share an element, so the popover is a dialog holding both.
  # See decisions/01-architecture.md.
  context "when searchable" do
    before do
      visit_preview(:select, :searchable)
      wait_for_stimulus
      within(preview) { find(trigger).click }
      expect(page).to have_css(content)
    end

    it "opens a dialog holding a search field and a separate listbox" do
      within(preview) do
        expect(find(content)["role"]).to eq("dialog")
        expect(find("[data-slot=select-list]")["role"]).to eq("listbox")
        expect(page).to have_css("[data-slot=select-input-wrapper] [data-slot=input-group-control]")
      end
    end

    it "gives the trigger a popup button's semantics rather than a combobox's" do
      within(preview) do
        expect(find(trigger)["role"]).to be_nil
        expect(find(trigger)["aria-haspopup"]).to eq("listbox")
      end
    end

    # Two deviations from upstream in one example. The field is named, which
    # upstream's is not — axe calls an unnamed one a critical `label` violation.
    # And it keeps `input-group-control` rather than upstream's `select-input`,
    # because this port's group raises its focus ring off that exact slot name.
    # The highlight cannot move DOM focus here: it would leave the search field
    # on the first arrow key and typing would stop. It becomes virtual instead —
    # `aria-activedescendant` on the field, pointing at the item that carries
    # `data-highlighted`.
    #
    # `banana` rather than `apple` because opening already highlights the first
    # item, so the first ArrowDown is a move off it.
    it "moves the highlight with the arrows while focus stays in the search field" do
      press(:arrow_down)

      expect(highlighted).to eq("banana")
      expect(page.evaluate_script("document.activeElement.dataset.slot")).to eq("input-group-control")
      expect(page.evaluate_script(<<~JS)).to be(true)
        (() => {
          const field = document.querySelector("[data-slot=select-input-wrapper] input")
          const id = field.getAttribute("aria-activedescendant")
          return !!id && document.getElementById(id).dataset.value === "banana"
        })()
      JS
    end

    # Substring, not prefix — which is what shadcn's aria variant does, and what
    # makes a filter worth having over the typeahead the plain select already
    # has. "err" is in the middle of Blueberry.
    it "narrows the list to substring matches, not just prefixes" do
      fill_in_search("err")

      expect(visible_item_values).to eq(%w[blueberry])
    end

    it "shows the empty state when nothing matches, and hides the list" do
      fill_in_search("zzz")

      within(preview) do
        expect(page).to have_css("[data-slot=select-empty]")
        expect(page).to have_no_css("[data-slot=select-list]")
      end
    end

    # The filtered-away rows are still in the DOM, so every consumer of
    # `enabledItems` has to skip them or the arrows walk into nothing.
    it "keeps the arrow keys inside what is left after filtering" do
      fill_in_search("p")
      press(:arrow_down)

      # apple, grapes and pineapple survive "p"; the highlight lands on the
      # first of them, so one ArrowDown reaches the second.
      expect(highlighted).to eq("grapes")
    end

    # `contentKeydown` is bound on the content and keystrokes from the field
    # bubble up to it, so three of its cases have to stand down: Space selects
    # there and is a character here, Home and End jump the highlight there and
    # move the caret here. The assertion that the panel is still open is the one
    # that matters — Space used to select, and selecting closes.
    it "lets the search field keep the keys that belong to a text field" do
      fill_in_search("g")
      press(:space)
      press(:home)

      within(preview) do
        expect(find("[data-slot=select-input-wrapper] input").value).to eq("g ")
        expect(page).to have_css(content)
      end
    end

    it "chooses the highlighted option with Enter" do
      fill_in_search("pine")
      press(:enter)

      within(preview) { expect(page).to have_no_css(content) }
      expect(value).to eq("pineapple")
    end

    it "starts from a clean query the next time it opens" do
      fill_in_search("pine")
      press(:escape)
      expect(page).to have_no_css(content)

      within(preview) { find(trigger).click }
      expect(page).to have_css(content)

      within(preview) do
        expect(find("[data-slot=select-input-wrapper] input").value).to eq("")
      end
      expect(visible_item_values).to eq(%w[apple banana blueberry grapes pineapple])
    end

    # The plain select colours its cursor with `focus:bg-accent`, which works
    # because the item really is focused. A searchable one keeps focus in the
    # field, so the cursor is only `data-highlighted` — and nothing styled that,
    # so the arrows moved and the panel looked frozen.
    #
    # Asserted on the computed colour rather than the attribute, because the
    # attribute was correct for the whole time this was broken. Every other
    # instrument here agreed: the specs checked `data-highlighted`, the
    # snapshots compared HTML, axe read roles. None of them can see a colour.
    it "shows which option the cursor is on" do
      background = page.evaluate_script(<<~JS)
        (() => {
          const root = [...document.querySelectorAll("[data-slot=select]")].pop()
          const item = root.querySelector("[data-slot=select-item][data-highlighted]")
          return getComputedStyle(item).backgroundColor
        })()
      JS

      expect(background).not_to eq("rgba(0, 0, 0, 0)")
    end

    it "names the search field and leaves the input-group's own hook intact" do
      within(preview) do
        field = find("[data-slot=select-input-wrapper] input")

        expect(field["aria-label"]).to be_present
        expect(field["data-slot"]).to eq("input-group-control")
      end
    end
  end
end
