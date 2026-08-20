# frozen_string_literal: true

require "spec_helper"

# Like the calendar, this component is rendered twice — `Schedule` packs the
# month on the server and `event_calendar_controller.js` packs it again for
# every month reached from the nav. So the first example is not about a feature.
# It is about the two packers agreeing, which is the thing this design risks:
# a bar in a different row after pressing › is the failure nothing else sees.
RSpec.describe "Event calendar", :js do
  # The server decides what "today" is and hands it to the controller, so
  # freezing Ruby's clock settles both sides. The browser's own clock is
  # deliberately not consulted — it can be a day off from `Time.zone`.
  around { |example| travel_to(Date.new(2026, 8, 12)) { example.run } }

  let(:calendar) { "[data-slot=event-calendar]" }
  let(:title) { "#{calendar} [data-slot=event-calendar-title]" }
  let(:agenda) { "#{calendar} [data-slot=event-calendar-agenda]" }

  def nav_button(label) = find("#{calendar} [data-slot=event-calendar-nav] button[aria-label='#{label}']")

  def day(date) = find("#{calendar} [data-day='#{date}']")

  def agenda_titles = all("#{calendar} [data-slot=event-calendar-agenda-event-title]", visible: :all).map(&:text)

  # Normalised, because the two renderers write attributes in their own order
  # and one of them goes through Rails' escaping. What is compared is everything
  # a person or a screen reader would tell apart: which cells exist, what state
  # each is in, and where every bar was laid.
  def month_in_the_page
    page.evaluate_script(<<~JS)
      (() => {
        const root = document.querySelector("#{calendar}")
        const days = [...root.querySelectorAll("[data-slot=event-calendar-day]")].map((cell) => ({
          day: cell.dataset.day,
          state: [ cell.dataset.today, cell.dataset.selected, cell.dataset.outside ].join("|"),
          label: cell.getAttribute("aria-label"),
          text: cell.textContent.trim(),
          dots: [...cell.querySelectorAll("[data-slot=event-calendar-day-dot]")].map((dot) => dot.dataset.color)
        }))
        const bars = [...root.querySelectorAll("[data-slot=event-calendar-event]")].map((bar) => ({
          color: bar.dataset.color,
          at: `${bar.style.gridColumn} / ${bar.style.gridRow}`,
          text: bar.textContent.trim(),
          cut: [ bar.dataset.continuesBefore, bar.dataset.continuesAfter ].join("|")
        }))

        return { days, bars, overflow: root.dataset.overflow || "", title: root.querySelector("[data-slot=event-calendar-title]").textContent }
      })()
    JS
  end

  it "draws the same month the server would have drawn", :aggregate_failures do
    visit_preview("event_calendar")
    wait_for_stimulus
    nav_button("Go to the Next Month").click
    expect(page).to have_css(title, text: "September 2026")
    nav_button("Go to the Previous Month").click
    expect(page).to have_css(title, text: "August 2026")
    in_the_browser = month_in_the_page

    visit "/lookbook/preview/shadcn/event_calendar/month?month=2026-08-01"
    expect(page).to have_css(title, text: "August 2026")
    from_the_server = month_in_the_page

    expect(in_the_browser).to eq(from_the_server)
    expect(in_the_browser["days"].size).to eq(42)
    expect(in_the_browser["bars"]).not_to be_empty
  end

  describe "the nav" do
    before do
      visit_preview("event_calendar")
      wait_for_stimulus
    end

    it "steps a month at a time in both directions", :aggregate_failures do
      nav_button("Go to the Next Month").click
      expect(page).to have_css(title, text: "September 2026")

      nav_button("Go to the Previous Month").click
      nav_button("Go to the Previous Month").click
      expect(page).to have_css(title, text: "July 2026")
    end

    it "comes back to today's month, on today", :aggregate_failures do
      nav_button("Go to the Next Month").click
      click_on "Today"

      expect(page).to have_css(title, text: "August 2026")
      expect(day("2026-08-12")["aria-pressed"]).to eq("true")
    end

    # A month whose cells all fit gets its extra row back. Asserted because the
    # attribute is the only thing standing between the "+2" line and the bar
    # above it, and it is set in two places.
    it "gives the cells back their row in a month that does not need one" do
      nav_button("Go to the Next Month").click

      expect(page).to have_css("#{calendar}:not([data-overflow])")
    end

    # The events a component was given are the ones the server had, and the
    # month you navigate to may have others. This is the only way a host can
    # find out, so it is a contract rather than an implementation detail.
    it "announces the month it moved to" do
      page.execute_script(<<~JS)
        window.movedTo = null
        document.addEventListener("shadcn--event-calendar:month-change", (event) => {
          window.movedTo = event.detail.month
        })
      JS
      nav_button("Go to the Next Month").click

      expect(page.evaluate_script("window.movedTo")).to eq("2026-09-01")
    end
  end

  describe "choosing a day" do
    before do
      visit_preview("event_calendar")
      wait_for_stimulus
    end

    it "reads that day's events out underneath", :aggregate_failures do
      day("2026-08-21").click

      expect(page).to have_css("#{agenda} [data-slot=event-calendar-agenda-title]", text: "Friday, August 21")
      expect(agenda_titles).to eq([ "Conference", "Birthday Party" ])
    end

    it "moves the pressed state off the day that had it", :aggregate_failures do
      day("2026-08-21").click

      expect(day("2026-08-21")["aria-pressed"]).to eq("true")
      expect(day("2026-08-20")["aria-pressed"]).to eq("false")
    end

    it "says so when there is nothing on the day", :aggregate_failures do
      day("2026-08-05").click

      expect(page).to have_css("#{agenda} [data-slot=event-calendar-agenda-empty]", text: "Nothing scheduled.")
      expect(agenda_titles).to be_empty
    end

    # The bars are decoration — `aria-hidden`, `pointer-events-none` — because
    # the day button already carries the count and the agenda reads the events
    # out in full. One tap target per day, at every width.
    it "keeps the day the only thing that can be clicked" do
      expect(page).to have_css("#{calendar} [data-slot=event-calendar-segments][aria-hidden=true]", visible: :all)
    end
  end

  # Not a narrower desktop: a different reading. Below `sm` a cell is a number
  # and its dots, and the events are read in the agenda — a cell that width can
  # hold a title or be legible, and not both.
  describe "on a phone" do
    before do
      page.driver.browser.manage.window.resize_to(390, 844)
      visit_preview("event_calendar")
      wait_for_stimulus
    end

    after { page.driver.browser.manage.window.resize_to(1400, 1000) }

    it "shows dots in the cells instead of bars", :aggregate_failures do
      expect(page).to have_css("#{calendar} [data-slot=event-calendar-day-dot]")
      expect(page).to have_no_css("#{calendar} [data-slot=event-calendar-event]")
    end

    it "still reads the day out underneath" do
      day("2026-08-21").click

      expect(agenda_titles).to eq([ "Conference", "Birthday Party" ])
    end
  end
end
