# frozen_string_literal: true

require "spec_helper"

# The calendar is the one component here that is rendered twice: `Calendar::Month`
# builds the grid on the server, and the controller builds it again for every
# month reached from the nav. So the first example is not about a feature — it is
# about the two renderers agreeing, which is the thing this design risks.
RSpec.describe "Calendar", :js do
  let(:calendar) { "[data-slot=calendar]" }
  let(:caption) { "#{calendar} [role=status]" }

  def grid = find("#{calendar} tbody")

  def focus_first_day
    page.execute_script(<<~JS)
      document.querySelector("#{calendar} tbody button[tabindex='0']").focus()
    JS
  end

  def focused_day
    page.evaluate_script("document.activeElement.closest('td')?.dataset.day")
  end

  def press_in_grid(key, shift: false)
    page.execute_script(<<~JS)
      document.activeElement.dispatchEvent(
        new KeyboardEvent("keydown", { key: "#{key}", shiftKey: #{shift}, bubbles: true })
      )
    JS
  end

  # Normalised because the two renderers write attributes in their own order and
  # Rails escapes `&` where `setAttribute` does not. What is compared is the set
  # of cells, their state and their labels — everything a person or a screen
  # reader would tell apart.
  def cells_of(scope)
    page.evaluate_script(<<~JS, scope)
      [...arguments[0].querySelectorAll("td")].map((cell) => ({
        day: cell.dataset.day,
        state: [ cell.dataset.outside, cell.dataset.today, cell.dataset.selected,
                 cell.dataset.disabled, cell.dataset.hidden ].join("|"),
        classes: cell.className.split(/\\s+/).sort().join(" "),
        label: cell.querySelector("button")?.getAttribute("aria-label"),
        text: cell.textContent.trim()
      }))
    JS
  end

  it "draws the same month the server would have drawn", :aggregate_failures do
    visit "/lookbook/preview/shadcn/calendar/default"
    wait_for_stimulus
    all("#{calendar} nav button").last.click
    expect(page).to have_css(caption, text: "September 2026")
    in_the_browser = cells_of(grid.native)

    visit "/lookbook/preview/shadcn/calendar/month?month=2026-09-01"
    expect(page).to have_css(caption, text: "September 2026")
    from_the_server = cells_of(grid.native)

    expect(in_the_browser).to eq(from_the_server)
    expect(in_the_browser.size).to eq(35)
  end

  describe "the nav" do
    before do
      visit "/lookbook/preview/shadcn/calendar/default"
      wait_for_stimulus
    end

    it "steps a month at a time in both directions", :aggregate_failures do
      all("#{calendar} nav button").last.click
      expect(page).to have_css(caption, text: "September 2026")

      all("#{calendar} nav button").first.click
      all("#{calendar} nav button").first.click
      expect(page).to have_css(caption, text: "July 2026")
    end

    # The month is the only thing that changes when the nav is pressed, and the
    # pressing hand is still on the button — so the caption is a live region
    # rather than something the reader has to go and look for.
    it "renames the grid with the month", :aggregate_failures do
      all("#{calendar} nav button").last.click

      expect(find("#{calendar} table")["aria-label"]).to eq("September 2026")
      expect(find(caption, visible: :all)["aria-live"]).to eq("polite")
    end

    # Rendered by the browser, so nothing here has been through Rails' escaping
    # or `I18n` — which is exactly why it is asserted: the names cross as values
    # rather than being formatted in JavaScript, and a `toLocaleDateString` would
    # answer to the browser's locale instead of the app's.
    it "keeps naming the days the way the server named them" do
      all("#{calendar} nav button").last.click

      expect(find("#{calendar} td[data-day='2026-09-02'] button")["aria-label"])
        .to eq("Wednesday, September 02, 2026")
    end

    it "leaves one day tabbable in the month it lands on", :aggregate_failures do
      all("#{calendar} nav button").last.click

      tabbable = all("#{calendar} tbody button[tabindex='0']")
      expect(tabbable.size).to eq(1)
      expect(tabbable.first.find(:xpath, "..")["data-day"]).to eq("2026-09-01")
    end
  end

  # `react-day-picker`'s own keys (`DayPicker.js:176-190`), which are the grid
  # pattern's: a day, a week, the ends of a week, and a month or a year on the
  # Page keys.
  describe "the keyboard" do
    before do
      visit "/lookbook/preview/shadcn/calendar/month?month=2026-09-01"
      wait_for_stimulus
      focus_first_day
    end

    it "moves a day at a time" do
      press_in_grid("ArrowRight")

      expect(focused_day).to eq("2026-09-02")
    end

    it "moves a week at a time", :aggregate_failures do
      press_in_grid("ArrowDown")
      expect(focused_day).to eq("2026-09-08")

      press_in_grid("ArrowUp")
      expect(focused_day).to eq("2026-09-01")
    end

    it "goes to the ends of the week, which start where the app says they do", :aggregate_failures do
      press_in_grid("ArrowRight")
      press_in_grid("Home")
      expect(focused_day).to eq("2026-08-31")

      press_in_grid("End")
      expect(focused_day).to eq("2026-09-06")
    end

    it "moves a month on the Page keys, and a year with Shift", :aggregate_failures do
      press_in_grid("PageDown")
      expect(focused_day).to eq("2026-10-01")

      press_in_grid("PageUp", shift: true)
      expect(focused_day).to eq("2025-10-01")
    end

    # The month follows the focus rather than the other way round — otherwise
    # the arrow keys stop at the edge of a month, which is where a person is
    # most likely to be going.
    it "carries the month with it when the focus leaves the month", :aggregate_failures do
      press_in_grid("ArrowLeft")

      expect(focused_day).to eq("2026-08-31")
      expect(page).to have_css(caption, text: "August 2026")
    end
  end

  describe "the dropdown caption" do
    before do
      visit "/lookbook/preview/shadcn/calendar/dropdown_caption"
      wait_for_stimulus
    end

    # Driven by setting the value rather than by Capybara's `select`: the
    # control is `opacity-0` — upstream's own class — and WebDriver calls an
    # element with no opacity undisplayed, so it refuses to operate it. What
    # that costs is covered by the example below, which asks the page whether a
    # pointer at the caption reaches the select at all.
    def choose(label, value)
      page.execute_script(<<~JS)
        const select = document.querySelector("#{calendar} select[aria-label='#{label}']")
        select.value = "#{value}"
        select.dispatchEvent(new Event("change", { bubbles: true }))
      JS
    end

    it "goes to the month it is set to" do
      choose("Choose the Month", 11)

      expect(page).to have_css(caption, visible: :all, text: "November 2026")
    end

    it "goes to the year it is set to" do
      choose("Choose the Year", 2028)

      expect(page).to have_css(caption, visible: :all, text: "August 2028")
    end

    # The technique the one-time-code field uses, and the property that makes it
    # honest: the control is invisible but *real*, so the pointer that appears to
    # be on the label is on the select.
    it "is the thing a pointer lands on, invisible or not" do
      reached = page.evaluate_script(<<~JS)
        (() => {
          const shown = document.querySelector("#{calendar} span[aria-hidden=true]")
          const box = shown.getBoundingClientRect()
          const hit = document.elementFromPoint(box.left + box.width / 2, box.top + box.height / 2)
          return hit?.tagName
        })()
      JS

      expect(reached).to eq("SELECT")
    end

    # The select is invisible and what a person reads is the span under it, so
    # the two have to move together — this is the same shape as the one-time-code
    # field, and the same thing to get wrong.
    # And in the same words: what the server writes in the label is the
    # *abbreviated* month, because the options are abbreviated, so a controller
    # writing the full name disagrees with the page it inherited.
    it "moves the label under the select with it", :aggregate_failures do
      all("#{calendar} nav button").last.click

      shown = all("#{calendar} span[aria-hidden=true]").map(&:text)
      expect(shown.first).to eq("Sep")
      expect(shown.last).to eq("2026")
    end

    it "stays inside its bounds", :aggregate_failures do
      12.times { all("#{calendar} nav button").first.click }

      expect(page).to have_css(caption, visible: :all, text: "August 2025")
      expect(find("#{calendar} select[aria-label='Choose the Year']", visible: :all).value).to eq("2025")
    end
  end
end
