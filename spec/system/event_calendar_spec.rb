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

  def open_panel
    find("#{calendar} [data-slot=event-calendar-nav] [data-slot=dropdown-menu-trigger]").click
  end

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
          marks: [...cell.querySelectorAll("[data-slot=event-calendar-day-tick]")].map((tick) => tick.dataset.color)
        }))
        const bars = [...root.querySelectorAll("[data-slot=event-calendar-event]")].map((bar) => ({
          color: bar.dataset.color,
          at: `${bar.style.gridColumn} / ${bar.style.gridRow}`,
          text: bar.textContent.trim(),
          cut: [ bar.dataset.continuesBefore, bar.dataset.continuesAfter ].join("|")
        }))

        return {
          days,
          bars,
          overflow: root.dataset.overflow || "",
          labelled: root.dataset.labelled || "",
          tick: root.style.getPropertyValue("--event-calendar-tick"),
          title: root.querySelector("[data-slot=event-calendar-title]").textContent
        }
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
      expect(day("2026-08-12")["aria-selected"]).to eq("true")
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

  # Forty-two tabbable buttons with no arrows and no geometry was the state
  # this shipped in; the gem's own `Calendar` has implemented the date-grid
  # pattern all along, two directories away.
  describe "the keyboard" do
    before do
      visit_preview("event_calendar")
      wait_for_stimulus
    end

    def focused = page.evaluate_script("document.activeElement?.dataset?.day")

    def press(key)
      page.execute_script(<<~JS)
        document.activeElement.dispatchEvent(new KeyboardEvent("keydown", { key: "#{key}", bubbles: true }))
      JS
    end

    it "gives the whole month one tab stop", :aggregate_failures do
      stops = all("#{calendar} [data-slot=event-calendar-day][tabindex='0']", visible: :all)

      expect(stops.size).to eq(1)
      expect(stops.first["data-day"]).to eq("2026-08-20")
    end

    it "moves by day and by week", :aggregate_failures do
      day("2026-08-20").click
      day("2026-08-20").native.send_keys(:arrow_right)
      expect(focused).to eq("2026-08-21")

      press("ArrowDown")
      expect(focused).to eq("2026-08-28")

      press("Home")
      expect(focused).to eq("2026-08-24")
    end

    # Stepping off the edge is a month change, and the tab stop goes with it.
    it "crosses the grid's edge into the next month", :aggregate_failures do
      day("2026-08-20").click
      day("2026-08-20").native.send_keys(:page_down)

      expect(page).to have_css("#{calendar} [data-slot=event-calendar-title]", text: "September 2026")
      expect(focused).to eq("2026-09-20")
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

    # `aria-selected` is absent rather than "false" on the days that are not,
    # which is what the gem's `Calendar` writes — and the tab stop travels with
    # it, so the month keeps exactly one.
    it "moves the selection, and the tab stop with it", :aggregate_failures do
      day("2026-08-21").click

      expect(day("2026-08-21")["aria-selected"]).to eq("true")
      expect(day("2026-08-20")["aria-selected"]).to be_nil
      expect(all("#{calendar} [data-slot=event-calendar-day][tabindex='0']", visible: :all).size).to eq(1)
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

  # Both cuts of a cell used to be rendered with one hidden, which made the menu
  # free and everything else twice as expensive. A cell renders the grouping it
  # is showing now, and the panel is links to the other state.
  describe "the options panel, as links" do
    before do
      visit "/lookbook/preview/shadcn/event_calendar/density?view=grid&most=8&colored=true"
      wait_for_stimulus
    end

    it "renders one grouping, not both", :aggregate_failures do
      expect(page).to have_css("#{calendar} [data-slot=event-calendar-day-item]")
      expect(page).to have_no_css("#{calendar} [data-slot=event-calendar-day-assignee]", visible: :all)
    end

    it "swaps which one on the server", :aggregate_failures do
      open_panel
      find("[data-slot=dropdown-menu-radio-item][data-value=assignees]").click

      expect(page).to have_css("#{calendar} [data-slot=event-calendar-day-assignee]")
      expect(page).to have_no_css("#{calendar} [data-slot=event-calendar-day-item]", visible: :all)
    end

    # One panel, two questions: which view, and the only question that view has.
    # The toolbar used to carry a control per answer, and two of them were
    # always about a view you were not in.
    it "asks which view first, then the question that view has", :aggregate_failures do
      open_panel

      expect(page.all("[data-slot=dropdown-menu-label]").map(&:text))
        .to eq([ "Show the month as", "Group cells by" ])
      expect(page.all("[data-slot=dropdown-menu-radio-item]").map(&:text))
        .to eq([ "Grid", "Rows", "Hours", "By assignee", "By event" ])
    end

    it "carries the month across to the hours view" do
      open_panel
      find("[data-slot=dropdown-menu-radio-item][data-value=hours]").click

      expect(page).to have_css("#{calendar} [data-slot=event-calendar-ruler]")
    end
  end

  # The workload reading is server-drawn — its cells hold crews and clients the
  # payload does not carry — so its nav dispatches and leaves the DOM alone.
  # Redrawing anyway is what put August's people on September's dates, and
  # re-deriving `labelled` from density alone is what ran both readings at once.
  describe "the workload reading's navigation", :aggregate_failures do
    it "announces the month and changes nothing else" do
      visit "/lookbook/preview/shadcn/event_calendar/workload"
      wait_for_stimulus

      moved = page.evaluate_script(<<~JS)
        (() => {
          let month = null
          document.addEventListener("shadcn--event-calendar:month-change", (e) => { month = e.detail.month },
                                    { once: true })
          document.querySelector("[data-slot=event-calendar-nav] button[aria-label='Go to the Next Month']").click()
          return month
        })()
      JS

      expect(moved).to eq("2026-09-01")
      expect(page).to have_css("#{calendar}:not([data-labelled])")
      expect(page).to have_no_css("#{calendar} [data-slot=event-calendar-day-tick]", visible: :all)
    end
  end

  # The `day_url:` path end to end, which only a browser can show. Two things
  # happen on one click and neither needs a line of JavaScript in the host:
  # Turbo sends the response into the frame inside the Sheet, and the dialog
  # action opens it. The model and the route are in `test/dummy` — the same
  # reason `/chat` exists for the message scroller.
  describe "a host putting the day view in a sheet" do
    let(:sheet) { "[data-slot=sheet-content]" }

    before do
      visit_preview("event_calendar", :with_turbo)
      wait_for_stimulus
    end

    it "starts closed, with no agenda of its own", :aggregate_failures do
      expect(page).to have_no_css("#{sheet}[data-state=open]")
      expect(page).to have_no_css("#{calendar} [data-slot=event-calendar-agenda]", visible: :all)
    end

    it "opens the sheet and fills it, on one click", :aggregate_failures do
      find("#{calendar} [data-day='2026-08-13']").click

      expect(page).to have_css("#{sheet}[data-state=open]")
      expect(page).to have_css("turbo-frame#day h2", text: "Thursday, August 13")
    end

    it "swaps a different day into the open sheet", :aggregate_failures do
      find("#{calendar} [data-day='2026-08-13']").click
      expect(page).to have_css("turbo-frame#day h2", text: "August 13")

      find("body").send_keys(:escape)
      find("#{calendar} [data-day='2026-08-20']").click

      expect(page).to have_css("turbo-frame#day h2", text: "August 20")
    end

    # The point of the example: a cell shows what a cell can show, and the rest
    # is one request away.
    it "shows the fields the calendar could not carry", :aggregate_failures do
      find("#{calendar} [data-day='2026-08-13']").click
      frame = find("turbo-frame#day")

      expect(frame).to have_link(href: %r{\Atel:})
      expect(frame.text).to include("Bologna")
      expect(frame.text).to match(/confirmed|pencilled|done/)
    end
  end

  # The one option whose effect is a stylesheet rather than a render. `rows:`
  # in `shadcn.css` carries the breakpoint and the override behind one name, so
  # what is asserted here is that both halves still fire: the width alone below
  # `lg`, and the attribute alone above it.
  #
  # It was a toggle button until the panel took it; the behaviour did not
  # change, only who asks for it.
  describe "the grid and rows views" do
    subject(:week) { find("#{calendar} [data-slot=event-calendar-week]", match: :first, visible: :all) }

    def display_of(node) = page.evaluate_script("getComputedStyle(arguments[0]).display", node)

    def paint(node) = page.evaluate_script("getComputedStyle(arguments[0]).backgroundColor", node)

    before do
      visit "/lookbook/preview/shadcn/event_calendar/density?view=grid&most=6"
      wait_for_stimulus
    end

    after { page.driver.browser.manage.window.resize_to(1400, 1000) }

    context "when the window is wide" do
      it "lays the month out as a grid until rows is asked for" do
        expect(display_of(week)).to eq("block")
      end

      it "lays it out as rows once it is", :aggregate_failures do
        open_panel
        find("[data-slot=dropdown-menu-radio-item][data-value=rows]").click

        expect(page).to have_css("#{calendar}[data-arrangement=rows]")
        expect(display_of(week)).to eq("contents")
      end

      # The half an eye can see. Asserted as a colour rather than a class,
      # because what matters is that a pressed toggle and an unpressed one do
      # not look alike — the pressed one borrows the solid `default` variant,
      # and a rename of that should not fail here.
      it "makes a pressed toggle look different from an unpressed one" do
        find("#{calendar} [data-slot=event-calendar-nav] [data-slot=button]", text: "Show all").click

        pressed = paint(find("#{calendar} [data-slot=button][aria-pressed=true]", text: "Show all"))

        expect(pressed).not_to eq(paint(find("#{calendar} [data-slot=button]", text: "Today")))
      end
    end

    context "when the window is narrow" do
      before do
        page.driver.browser.manage.window.resize_to(820, 900)
        visit "/lookbook/preview/shadcn/event_calendar/density?view=grid&most=6"
        wait_for_stimulus
      end

      # The breakpoint alone, with nothing asked for: below `lg` the grid view
      # is rows anyway, because seven columns on a phone is what rows avoid.
      it "is already rows" do
        expect(display_of(week)).to eq("contents")
      end
    end
  end

  # The hours reading draws its scale once, above the month, so the only thing
  # keeping an hour label over the gridline it names is that the two boxes are
  # the same box. Nothing else in the suite can see that: the scale and the
  # axis are different elements, both render, and axe has no opinion.
  #
  # They were 16px apart, which is a day cell's `px-2` and `gap-2` — the scale
  # is not inside a cell and had neither.
  describe "the hour scale" do
    before do
      visit "/lookbook/preview/shadcn/event_calendar/density?view=hours&most=6"
      wait_for_stimulus
    end

    it "sits over the axis it names, to the pixel", :aggregate_failures do
      boxes = page.evaluate_script(<<~JS)
        (() => {
          const scale = document.querySelector("[data-slot=event-calendar-ruler] > span:last-child")
          const axis = [...document.querySelectorAll("[data-slot=event-calendar-day-track]")]
                         .find((t) => t.offsetParent)
          const [a, b] = [scale.getBoundingClientRect(), axis.getBoundingClientRect()]
          return { left: Math.round(b.left - a.left), width: Math.round(b.width - a.width) }
        })()
      JS

      expect(boxes["left"]).to eq(0)
      expect(boxes["width"]).to eq(0)
    end
  end

  # A component spec can only see what the style attribute says, and it said
  # `--for:100%` while the chip rendered 124px wide inside a 1270px axis: the
  # class carried both `w-auto` and `w-(--for)`, and the one Tailwind emitted
  # last won. Only a browser can tell those two apart.
  describe "an all-day chip in the hours reading" do
    before do
      visit "/lookbook/preview/shadcn/event_calendar/density?view=hours&most=2&all_day=1&from=7&to=19"
      wait_for_stimulus
    end

    it "is as wide as the day" do
      widths = page.evaluate_script(<<~JS)
        (() => {
          const chip = [...document.querySelectorAll("[data-slot=event-calendar-day-item]")]
            .find((c) => c.style.cssText.includes("--for") && c.offsetParent)
          const axis = chip.closest("[data-slot=event-calendar-day-track]")
          return { chip: Math.round(chip.getBoundingClientRect().width),
                   axis: Math.round(axis.getBoundingClientRect().width) }
        })()
      JS

      expect(widths["chip"]).to eq(widths["axis"])
    end

    # The width's consequence, and the reason this is measured rather than
    # eyeballed: the crew rides `ml-auto` to the end of the head, which is right
    # at 124px and absurd at 1270 — the faces a metre from the label they belong
    # to. Asserted as the gap between them, so it cannot pass by the chip having
    # quietly stopped being wide.
    it "keeps the crew beside the label, not at the far end" do
      gap = page.evaluate_script(<<~JS)
        (() => {
          const chip = [...document.querySelectorAll("[data-slot=event-calendar-day-item]")]
            .find((c) => c.style.cssText.includes("--for") && c.offsetParent &&
                         c.querySelector("[data-slot=avatar-group]"))
          const label = chip.querySelector("[data-slot=event-calendar-day-time]")
          const crew = chip.querySelector("[data-slot=avatar-group]")
          return Math.round(crew.getBoundingClientRect().left - label.getBoundingClientRect().right)
        })()
      JS

      expect(gap).to be < 16
    end
  end

  # The whole point of the lanes, and the only place it can be checked: a job
  # that crosses days has to land on the same row in every cell it appears in,
  # or it reads as several jobs that happen to share a name. Two things can
  # break it and neither is visible in HTML — a row held open that is shorter
  # than a real one, and a band that starts wherever the day above it ends.
  describe "a job that crosses days, across a week" do
    it "sits on one line in every cell" do
      visit "/lookbook/preview/shadcn/event_calendar/density" \
            "?view=grid&most=30&all_day=1&spanning=2&group=events"
      wait_for_stimulus

      rows = page.evaluate_script(<<~JS)
        (() => {
          const rows = {}
          for (const cell of document.querySelectorAll("[data-slot=event-calendar-day]")) {
            for (const chip of cell.querySelectorAll("[data-slot=event-calendar-day-item]")) {
              const text = chip.querySelector("[data-slot=event-calendar-day-text]")
              if (!text || !text.textContent.includes("day job")) continue
              ;(rows[text.textContent.trim()] ||= []).push(
                Math.round(chip.getBoundingClientRect().top - cell.getBoundingClientRect().top))
            }
          }
          return rows
        })()
      JS

      expect(rows.values).to all(satisfy { |tops| tops.uniq.one? })
    end
  end

  # A workload row is a fixed 80px of chips that scroll sideways, and nothing
  # asserted it: its rules moved out of the shared frame when the hours reading
  # needed a cell that grows with its lanes, the move silently did not land, and
  # three commits shipped with rows that were as tall as their contents.
  #
  # It also has no band to align. A day is a row there, so what would have to
  # line up is an *x*, and that is decided by the widths of the chips before it
  # — 193, 202 and 214 pixels for three of them, because a chip is as wide as
  # its client's name and its crew. The held rows are a grid idea and are
  # hidden here.
  describe "the rows arrangement" do
    before do
      visit "/lookbook/preview/shadcn/event_calendar/density" \
            "?view=rows&most=6&all_day=1&spanning=3&group=events"
      wait_for_stimulus
    end

    it "keeps every row the same fixed height" do
      heights = page.evaluate_script(<<~JS)
        [...document.querySelectorAll("[data-slot=event-calendar-day]")]
          .filter((cell) => cell.offsetParent)
          .map((cell) => Math.round(cell.getBoundingClientRect().height))
      JS

      expect(heights.uniq).to eq([ 80 ])
    end

    it "draws no held row, having nothing to hold one for" do
      expect(page).to have_no_css("#{calendar} [data-slot=event-calendar-day-held]")
    end
  end

  # A server-drawn reading has no other way to change month: its cells hold
  # crews and clients `#portable_events` does not carry, so the controller
  # announces the ask and leaves the DOM alone. `month_url:` is the whole of its
  # navigation, and what a host wires to its own route.
  describe "walking the months in a server-drawn reading" do
    it "moves and keeps the view it was in", :aggregate_failures do
      visit "/lookbook/preview/shadcn/event_calendar/density?month=2026-08-01&view=hours&most=4"
      wait_for_stimulus

      2.times { find("#{calendar} [aria-label='Go to the Next Month']").click }

      expect(page).to have_css("#{calendar} [data-slot=event-calendar-title]", text: "October 2026")
      expect(page).to have_css("#{calendar} [data-slot=event-calendar-ruler]")

      find("#{calendar} [aria-label='Go to the Previous Month']").click

      expect(page).to have_css("#{calendar} [data-slot=event-calendar-title]", text: "September 2026")
    end

    # `Today` is the same link with `Date.current` in it, so it comes back from
    # anywhere in one step rather than stepping back a month at a time. It was
    # dead for as long as the preview passed no `month_url:` — which is also
    # what a host that passes none gets, by contract: the controller announces
    # `month-change` and leaves the DOM alone.
    it "comes back to this month from wherever it is" do
      visit "/lookbook/preview/shadcn/event_calendar/density?month=2026-10-01&view=grid&most=3"
      wait_for_stimulus

      find("#{calendar} [data-slot=event-calendar-nav] [data-slot=button]", text: "Today").click

      expect(page).to have_css("#{calendar} [data-slot=event-calendar-title]",
                               text: I18n.l(Date.current, format: "%B %Y"))
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

    it "shows marks in the cells instead of bars", :aggregate_failures do
      expect(page).to have_css("#{calendar} [data-slot=event-calendar-day-tick]")
      expect(page).to have_no_css("#{calendar} [data-slot=event-calendar-event]")
    end

    it "still reads the day out underneath" do
      day("2026-08-21").click

      expect(agenda_titles).to eq([ "Conference", "Birthday Party" ])
    end
  end
end
