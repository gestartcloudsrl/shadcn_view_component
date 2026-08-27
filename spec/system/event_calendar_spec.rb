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

  # Clicking a trigger is not the same as having a menu: the panel's items are
  # links, so a click that lands while Turbo is still swapping pages hits the
  # *old* trigger — and because that menu is open, the click closes it rather
  # than opening anything. Waiting on the content's own state is what tells the
  # two apart, and turns a silently closed menu into a failure that says so
  # instead of an empty list three lines further down.
  def open_panel
    find("#{calendar} [data-slot=event-calendar-nav] [data-slot=dropdown-menu-trigger]").click
    find("#{calendar} [data-slot=event-calendar-nav] [data-slot=dropdown-menu-content][data-state=open]")
  end

  def nav_button(label) = find("#{calendar} [data-slot=event-calendar-nav] button[aria-label='#{label}']")

  def day(date) = find("#{calendar} [data-day='#{date}']")

  # Read twice in one example, before and after a scroll, so it cannot be a
  # `let`.
  def frame_offscreen?
    page.evaluate_script(<<~JS)
      (() => {
        const frame = document.querySelector("turbo-frame#day")
        if (!frame) return null

        const box = frame.getBoundingClientRect()
        return box.top >= window.innerHeight || box.bottom <= 0
      })()
    JS
  end

  # A method, not a `let`: it is asked the same question about two cells and in
  # two palettes within one example. The cell is found inside the script rather
  # than passed in — Capybara hands an element argument to a wrapper this does
  # not sit inside, and the call comes back empty.
  # Which element is painted on top, over the middle of a named bar. No
  # attribute records that, and the layer the bars live in is
  # `pointer-events-none`, so a hit test cannot reach them — switching that on
  # for the length of the question changes what *answers* a hit test, not what
  # is drawn above what.
  def topmost_over(title)
    page.evaluate_script(<<~JS)
      (() => {
        const chip = document.querySelector("#{calendar} [data-slot=event-calendar-event][title='#{title}']")
        if (!chip) return "assente"

        const layer = chip.closest("[data-slot=event-calendar-segments]")
        const was = layer.style.pointerEvents

        chip.scrollIntoView({ block: "center" })
        const box = chip.getBoundingClientRect()

        layer.style.pointerEvents = "auto"
        const hit = document.elementFromPoint(box.left + box.width / 2, box.top + box.height / 2)
        layer.style.pointerEvents = was

        if (hit?.closest("[data-slot=event-calendar-event]")) return "event-calendar-event"
        return hit?.closest("[data-slot]")?.dataset?.slot ?? "nothing"
      })()
    JS
  end

  def outline_of(date)
    page.evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector("[data-slot=event-calendar-day][data-day='#{date}']")
        if (!el) return "assente"

        const s = getComputedStyle(el)
        return s.outlineStyle === "none" ? "none" : `${s.outlineWidth} ${s.outlineStyle}`
      })()
    JS
  end

  def agenda_titles = all("#{calendar} [data-slot=item-title]", visible: :all).map(&:text)

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

    # `aria-selected` is the fact; this is whether anyone can see it. The tint
    # alone separated a selected cell from a plain one by 0.030 of perceptual
    # lightness in the light palette against 0.124 in the dark, which is why
    # clicking a day read as nothing happening. Asserted in both palettes for
    # that reason — the one that was too weak is the one the specs emulate.
    it "marks the selected day with something visible, in either palette", :aggregate_failures do
      day("2026-08-21").click

      %w[light dark].each do |palette|
        page.execute_script("document.documentElement.classList.toggle('dark', #{palette == 'dark'})")

        expect(outline_of("2026-08-21")).to eq("2px solid")
        expect(outline_of("2026-08-20")).to eq("none")
      end
    end

    # The outline that makes the selection visible sits on the cell, and the cell
    # is opaque — so raising it above the bar layer to keep the outline off its
    # neighbours hid every bar crossing it. "Conference" runs the 19th to the
    # 21st, so its middle is over the selected day rather than beside it.
    it "still draws the bars crossing the day it selected" do
      expect(topmost_over("Conference")).to eq("event-calendar-event")
    end

    # The same cell property, reached the other way: `focus-visible` raises a
    # cell too, and it is the older of the two — so the day a keyboard is
    # standing on hid its own events before a selection could.
    it "still draws them under the day the keyboard is on", :aggregate_failures do
      day("2026-08-20").click
      press(:arrow_right)

      expect(page.evaluate_script("document.activeElement.dataset.day")).to eq("2026-08-21")
      expect(topmost_over("Birthday Party")).to eq("event-calendar-event")
      # And the ring the cell was being raised for is still drawn, which is the
      # half of the fix that is an argument rather than an observation
      # everywhere else: it is `ring-inset`, so it was never at risk.
      expect(page.evaluate_script("getComputedStyle(document.activeElement).boxShadow")).to include("inset")
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
      page.driver.browser.manage.window.resize_to(1400, 1000)
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

    # One panel, narrowing: the period, then how to read it, then the only
    # question that reading has. The toolbar used to carry a control per answer,
    # and most of them were always about a view you were not in.
    it "narrows from the period to the question the view has", :aggregate_failures do
      open_panel

      expect(page.all("[data-slot=dropdown-menu-label]").map(&:text))
        .to eq([ "Show", "Show the month as", "Group cells by" ])
      expect(page.all("[data-slot=dropdown-menu-radio-item]").map(&:text))
        .to eq([ "Monthly", "Daily", "Grid", "Rows", "Hours", "By assignee", "By event" ])
    end

    # A day has one arrangement, so the monthly question goes; the grouping
    # stays, because "who is where" is a question a day gets asked more than a
    # month does.
    it "swaps the monthly question for the day's own", :aggregate_failures do
      open_panel
      find("[data-slot=dropdown-menu-radio-item][data-value=daily]").click
      # The item is a link, so the day arrives over Turbo — and the trigger is
      # the one element that says which page you are on, because it names the
      # state it opens. Without this the panel is opened on whichever page
      # happens to be mounted, which is the month often enough to pass.
      expect(page).to have_css("#{calendar} [data-slot=dropdown-menu-trigger]", text: "Daily")

      open_panel

      expect(page.all("[data-slot=dropdown-menu-label]").map(&:text))
        .to eq([ "Show", "Show the day as", "Group cells by" ])
      expect(page.all("[data-slot=dropdown-menu-radio-item]").map(&:text))
        .to eq([ "Monthly", "Daily", "Hours only", "List only", "Hours and list",
                 "By assignee", "By event" ])
    end

    # The period and the view are two questions, and the answer to one has to
    # survive the other. It did not: the panel's *Monthly* item was given
    # `view_url.call(:grid)`, so a host that keeps the two apart could not tell
    # "show me the month again" from "draw the month as a grid" — leaving the
    # day sent you back to grid however you had been reading the month. The
    # callback now says `:monthly`.
    it "comes back to the view it was reading the month in", :aggregate_failures do
      visit "/lookbook/preview/shadcn/event_calendar/density?view=hours&most=4"
      wait_for_stimulus

      open_panel
      find("[data-slot=dropdown-menu-radio-item][data-value=daily]").click
      expect(page).to have_css("#{calendar} [data-slot=dropdown-menu-trigger]", text: "Daily")

      open_panel
      find("[data-slot=dropdown-menu-radio-item][data-value=monthly]").click

      expect(page).to have_css("#{calendar} [data-slot=dropdown-menu-trigger]", text: "Monthly")
      expect(page).to have_css("#{calendar} [data-slot=dropdown-menu-trigger]", text: "Hours")
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
      page.driver.browser.manage.window.resize_to(1300, 900)
      visit "/lookbook/preview/shadcn/event_calendar/density?turbo=panel&month=2026-08-01"
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

  # The other half of the same idea, and the cheaper one: the day view goes into
  # the agenda the calendar already has, rather than into a Sheet. `agenda_as:`
  # is what makes that possible, and it was asserted only at the component level
  # — that the element is a `turbo-frame` and the cell names it. Whether a click
  # then actually swaps a day into it is a browser's question, and nothing was
  # asking it.
  describe "a host owning the day view, in the agenda" do
    before do
      page.driver.browser.manage.window.resize_to(1300, 900)
      visit "/lookbook/preview/shadcn/event_calendar/density?turbo=agenda&month=2026-08-01"
      wait_for_stimulus
    end

    it "makes the day a link rather than a button" do
      expect(page).to have_css("a[data-slot=event-calendar-day][data-day='2026-08-13']")
    end

    it "swaps the day into the agenda, and swaps it again", :aggregate_failures do
      find("#{calendar} [data-day='2026-08-13']").click
      expect(page).to have_css("turbo-frame#day h2", text: "Thursday, August 13")

      find("#{calendar} [data-day='2026-08-20']").click
      expect(page).to have_css("turbo-frame#day h2", text: "Thursday, August 20")
    end

    # The half that swapping does not cover, and the half a person notices: the
    # agenda sits under six weeks of grid, so the frame updated 335px below the
    # fold and the click read as nothing happening. Turbo's `autoscroll` brings
    # it up. Asserted as *in the viewport* rather than as "the attribute is
    # there", because the attribute was never the claim.
    it "brings the day into view rather than updating it off-screen" do
      expect(frame_offscreen?).to be(true)

      find("#{calendar} [data-day='2026-08-13']").click
      expect(page).to have_css("turbo-frame#day h2", text: "Thursday, August 13")

      expect(page.document).to have_selector(:xpath, "//*", wait: 0) # settle
      expect(frame_offscreen?).to be(false)
    end
  end

  # A reading the server draws whole ships no `prototypes` template, because
  # there is nothing to redraw from — and `connect` read it regardless, so the
  # controller threw on every one of them. Nothing visibly broke, which is why
  # it lasted: Stimulus catches the throw and `data-action` binds independently,
  # so the keyboard and the selection went on working. What shipped was a
  # console error on every page a host puts one of these on.
  #
  # Asserted per reading rather than once, because the three arrive at it
  # differently — two arrangements of workload and a different component for
  # hours — and a guard that covered one would look like it covered all.
  describe "a reading the server draws whole" do
    %w[workload workload_by_assignee hours].each do |preview|
      it "connects its controller without throwing, on #{preview}" do
        page.driver.browser.logs.get(:browser)
        visit "/lookbook/preview/shadcn/event_calendar/#{preview}"
        wait_for_stimulus

        errors = page.driver.browser.logs.get(:browser).reject { |log| log.level == "WARNING" }

        expect(errors).to be_empty, -> { errors.map(&:message).join("\n\n") }
      end
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
    # A chip drawn at its duration can still be narrower than its own clock,
    # three faces and a "+1" — and `overflow-hidden` cut the crew in half rather
    # than letting it be as wide as what it says. The duration is a floor for
    # the width, not a cap.
    #
    # Both halves are asserted together because each alone has a trivial wrong
    # answer: nothing clips if every chip is enormous, nothing overlaps if every
    # chip is tiny.
    it "cuts nothing off, and still overlaps nothing", :aggregate_failures do
      counts = page.evaluate_script(<<~JS)
        (() => {
          let clipped = 0, overlaps = 0
          for (const chip of document.querySelectorAll("[data-slot=event-calendar-day-item]"))
            if (chip.scrollWidth > chip.clientWidth + 1) clipped++
          for (const axis of document.querySelectorAll("[data-slot=event-calendar-day-track]")) {
            const b = [...axis.querySelectorAll("[data-slot=event-calendar-day-item]")]
              .map((c) => c.getBoundingClientRect())
            for (let i = 0; i < b.length; i++) for (let j = i + 1; j < b.length; j++)
              if (Math.min(b[i].right, b[j].right) - Math.max(b[i].left, b[j].left) > 1 &&
                  Math.min(b[i].bottom, b[j].bottom) - Math.max(b[i].top, b[j].top) > 1) overlaps++
          }
          return { clipped, overlaps }
        })()
      JS

      expect(counts["clipped"]).to eq(0)
      expect(counts["overlaps"]).to eq(0)
    end

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

    # A held row is `invisible`, which keeps its layout space — so a driver
    # reporting it as "not displayed" would pass this whether or not the rule
    # that removes it exists. The computed `display` is the only thing that can
    # tell those apart, and removing it is the point: in a strip the space is
    # a meaningless indent.
    it "takes no space for a held row, having nothing to align" do
      displays = page.evaluate_script(<<~JS)
        [...document.querySelectorAll("[data-slot=event-calendar-day-held]")]
          .map((held) => getComputedStyle(held).display)
      JS

      expect(displays.uniq - [ "none" ]).to be_empty
    end
  end

  # A server-drawn reading has no other way to change month: its cells hold
  # crews and clients `#portable_events` does not carry, so the controller
  # announces the ask and leaves the DOM alone. `month_url:` is the whole of its
  # navigation, and what a host wires to its own route.
  describe "walking the months in a server-drawn reading" do
    # Explicit, because these examples read a desktop layout and the suite runs
    # in a random order behind ones that resize the window to a phone.
    before { page.driver.browser.manage.window.resize_to(1400, 1000) }

    it "moves and keeps the view it was in", :aggregate_failures do
      visit "/lookbook/preview/shadcn/event_calendar/density?month=2026-08-01&view=hours&most=4"
      wait_for_stimulus

      # One month at a time, each waited for. Clicking twice in a row raced the
      # navigation the first click starts: the second `find` could resolve
      # against the page on its way out, and the month it asked for was the one
      # already being left — August to September, twice. Roughly one run in
      # four, and the same shape as the options panel's flake, which is why the
      # cure is the same one: wait for the page you are about to click on.
      %w[September October].each do |month|
        find("#{calendar} [aria-label='Go to the Next Month']").click
        expect(page).to have_css("#{calendar} [data-slot=event-calendar-title]", text: "#{month} 2026")
      end
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

  # A month needs its date column because forty-two rows have to say which is
  # which; a day does not, and it was charging the axis a `w-14` to repeat what
  # the title already says. Hidden in CSS, so only a browser can see it gone.
  describe "the daily reading" do
    before do
      page.driver.browser.manage.window.resize_to(1400, 1000)
      visit "/lookbook/preview/shadcn/event_calendar/density" \
            "?period=daily&month=2026-08-04&most=8&from=7&to=19"
      wait_for_stimulus
    end

    # The same check the month's scale gets, and it needs its own because the
    # left column is a different width here — the operator's name at `w-32` cut
    # by operator, nothing at all cut by event. The two were 72 pixels apart.
    %w[assignees events].each do |group|
      it "sits its scale over the axis, cut by #{group}", :aggregate_failures do
        visit "/lookbook/preview/shadcn/event_calendar/density" \
              "?period=daily&month=2026-08-01&most=10&group=#{group}&from=7&to=19"
        wait_for_stimulus

        boxes = page.evaluate_script(<<~JS)
          (() => {
            const scale = document.querySelector("[data-slot=event-calendar-ruler] > span:last-child")
            const axis = [...document.querySelectorAll("[data-slot=event-calendar-day-track]")]
                           .find((track) => track.offsetParent)
            const [a, b] = [scale.getBoundingClientRect(), axis.getBoundingClientRect()]
            return { left: Math.round(b.left - a.left), width: Math.round(b.width - a.width) }
          })()
        JS

        expect(boxes["left"]).to eq(0)
        expect(boxes["width"]).to eq(0)
      end
    end

    it "gives the axis the whole width", :aggregate_failures do
      expect(page).to have_no_css("#{calendar} [data-slot=event-calendar-day-head]")
      expect(page).to have_css("#{calendar} [data-slot=event-calendar-ruler]")
    end

    it "walks a day at a time" do
      find("#{calendar} [aria-label='Go to the Next Day']").click

      expect(page).to have_css("#{calendar} [data-slot=event-calendar-title]",
                               text: "Wednesday, August 5")
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
