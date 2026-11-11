# frozen_string_literal: true

require "spec_helper"

# What the rendered month says, as opposed to what it looks like — the looks are
# `snapshot_spec`'s and the behaviour is `spec/system/event_calendar_spec.rb`'s.
# These are the computed values in between: the accessible names, the counts,
# and the two contracts the controller depends on and nothing else would catch.
RSpec.describe Shadcn::EventCalendar::Component do
  subject(:calendar) { described_class.new(month: Date.new(2026, 8, 1), **options) }

  let(:options) { {} }
  # Everything except the `<template>` of prototypes. A browser treats a
  # template's contents as inert and out of the document; Nokogiri parses them
  # as ordinary children, so `slots("event-calendar-event")` would otherwise
  # count the shape the controller clones alongside the bars the month drew.
  let(:painted) do
    Nokogiri::HTML5.fragment(rendered_content.to_s).tap { |doc| doc.css("template").remove }
  end

  around { |example| travel_to(Date.new(2026, 8, 12)) { example.run } }


  def parts(name) = painted.css(%(*[data-slot="#{name}"]))

  # Enough on one day to put the calendar past `DENSE_ABOVE`. Inline rather than
  # a shared fixture: the gallery has no dense preview any more, and a generator
  # nothing renders is a generator nobody maintains.
  def forty_on_one_day
    Array.new(40) do |index|
      { title: "Booking #{index + 1}", starts_at: Time.zone.local(2026, 8, 20, 7 + (index % 12), index) }
    end
  end

  def day(date) = painted.at_css(%(*[data-day="#{date}"]))

  describe "the day buttons" do
    let(:options) do
      { events: [
        { title: "Standup", starts_at: Time.zone.local(2026, 8, 20, 9) },
        { title: "Lunch", starts_at: Time.zone.local(2026, 8, 20, 12) },
        { title: "Team Sync", starts_at: Time.zone.local(2026, 8, 12, 9) }
      ] }
    end

    before { render_inline(calendar) }

    it "names a day by its date alone when nothing is on it" do
      expect(day("2026-08-21")["aria-label"]).to eq("Friday, August 21, 2026")
    end

    # The name has to contain what the button shows, or a voice-control user
    # saying "click 3" has nothing to match: "August 03" does not contain the
    # "3" on the face. axe 4.14 checks it (`label-content-name-mismatch`).
    # Upstream's day picker says "August 3rd", which does.
    it "writes a single-digit day the way the button shows it" do
      expect(day("2026-08-03")["aria-label"]).to eq("Monday, August 3, 2026")
    end

    it "adds the count to the name when something is" do
      expect(day("2026-08-20")["aria-label"]).to eq("Thursday, August 20, 2026, 2 events")
    end

    # The controller has to pluralise a count the server never saw, so the forms
    # cross rather than the sentence — `Intl.PluralRules` picks on the far side.
    it "reads the singular for one" do
      expect(day("2026-08-12")["aria-label"]).to eq("Wednesday, August 12, 2026, 1 event")
    end

    it "marks today" do
      expect(day("2026-08-12")["aria-current"]).to eq("date")
    end

    it "marks the days that belong to a neighbouring month" do
      expect(day("2026-07-31")["data-outside"]).to eq("true")
    end
  end

  describe "the selected day" do
    it "is today when today is in the month" do
      render_inline(calendar)

      expect(day("2026-08-12")["aria-selected"]).to eq("true")
    end

    context "when the month is not the one today falls in" do
      subject(:calendar) { described_class.new(month: Date.new(2026, 11, 1)) }

      it "is the first of the month" do
        render_inline(calendar)

        expect(day("2026-11-01")["aria-selected"]).to eq("true")
      end
    end

    context "when the caller names one" do
      let(:options) { { selected: Date.new(2026, 8, 25) } }

      it "is the one the caller named" do
        render_inline(calendar)

        expect(day("2026-08-25")["aria-selected"]).to eq("true")
      end
    end
  end

  describe "the agenda" do
    let(:options) do
      { selected: Date.new(2026, 8, 20),
        events: [
          { title: "Conference", starts_at: Date.new(2026, 8, 19), ends_at: Date.new(2026, 8, 21) },
          { title: "Meeting", starts_at: Time.zone.local(2026, 8, 20, 10, 30),
            ends_at: Time.zone.local(2026, 8, 20, 11, 30) },
          { title: "Elsewhere", starts_at: Date.new(2026, 8, 25) }
        ] }
    end

    before { render_inline(calendar) }

    # The row is an `Item`: a content, a title and a description, which is the
    # shape it had already when it was written out by hand.
    it "describes a row with the Item family's own parts", :aggregate_failures do
      expect(parts("item-title").map(&:text)).to eq(%w[Conference Meeting])
      expect(parts("item-description").map(&:text).last).to eq("10:30 AM – 11:30 AM")
      # The colour is still a slot of the calendar's own — a bar now rather than
      # a dot, because a row is two lines and a dot marks one.
      expect(parts("event-calendar-agenda-mark").map { |mark| mark["class"] })
        .to all(include("self-stretch"))
    end

    it "lists the selected day's events and nothing else" do
      expect(parts("item-title").map(&:text)).to eq(%w[Conference Meeting])
    end

    it "reads a timed event as a span of the clock" do
      expect(parts("item-description").map(&:text).last).to eq("10:30 AM – 11:30 AM")
    end

    it "reads a multi-day event as a span of days" do
      expect(parts("item-description").map(&:text).first).to eq("Aug 19 – Aug 21")
    end

    it "hides the empty line" do
      expect(painted.at_css(%(*[data-slot="event-calendar-agenda-empty"]))["hidden"]).to be_present
    end

    context "when nothing is on the selected day" do
      let(:options) { { selected: Date.new(2026, 8, 20) } }

      it "shows the empty line" do
        expect(painted.at_css(%(*[data-slot="event-calendar-agenda-empty"]))["hidden"]).to be_nil
      end
    end
  end

  describe "overflow" do
    let(:options) do
      { max_events: 2,
        events: 4.times.map { |slot| { title: "Slot #{slot}", starts_at: Time.zone.local(2026, 8, 20, 9 + slot) } } }
    end

    before { render_inline(calendar) }

    it "draws only the bars the cell has room for" do
      expect(parts("event-calendar-event").size).to eq(2)
    end

    it "counts the rest on the day they fell off" do
      expect(day("2026-08-20").at_css(%(*[data-slot="event-calendar-day-more"])).text).to eq("+2")
    end

    # The cells grow by a row when a month needs the line, and only then; the
    # controller sets the same attribute when it draws a month of its own.
    it "asks the cells for the extra row" do
      expect(root["data-overflow"]).to eq("true")
    end
  end

  # The second reading, and the one a phone gets at any density: one mark per
  # event rather than a sample and a count.
  describe "the marks" do
    let(:options) do
      { events: [
        { title: "A", starts_at: Time.zone.local(2026, 8, 20, 9), color: :blue },
        { title: "B", starts_at: Time.zone.local(2026, 8, 20, 10), color: :rose },
        { title: "C", starts_at: Time.zone.local(2026, 8, 20, 11), color: :blue }
      ] }
    end

    before { render_inline(calendar) }

    it "draws one per event, not one per lane" do
      expect(day("2026-08-20").css(%(*[data-slot="event-calendar-day-tick"])).size).to eq(3)
    end

    # Grouped by colour rather than by the clock, in the palette's own order, so
    # a cell reads as bands and two cells can be compared. `Component#in_bands`
    # says why the agenda disagrees.
    it "bands them by colour, in the palette's order" do
      colors = day("2026-08-20").css(%(*[data-slot="event-calendar-day-tick"])).map { |tick| tick["data-color"] }

      expect(colors).to eq(%w[blue blue rose])
    end

    it "closes the gap inside a band and not across one", :aggregate_failures do
      ticks = day("2026-08-20").css(%(*[data-slot="event-calendar-day-tick"]))

      expect(ticks.map { |tick| tick["data-run-after"] }).to eq([ "true", nil, nil ])
      expect(ticks.map { |tick| tick["data-run-before"] }).to eq([ nil, "true", nil ])
    end

    it "sizes them against the busiest day in the month" do
      expect(root["style"]).to include("--event-calendar-tick:0.4375rem")
    end

    context "when a day holds more than a cell can name" do
      let(:options) { { events: forty_on_one_day } }

      it "shrinks the marks to what a hundred of them cost" do
        expect(root["style"]).to include("--event-calendar-tick:0.3125rem")
      end

      # A cell either names its events or shows their shape, never half of
      # each — so past `DENSE_ABOVE` the bars and the "+2" go away at every
      # width and the marks are the only reading.
      it "stops naming them at any width", :aggregate_failures do
        expect(root["data-labelled"]).to be_nil
        expect(root["data-overflow"]).to be_nil
      end

      it "still draws every one of them" do
        expect(day("2026-08-20").css(%(*[data-slot="event-calendar-day-tick"])).size).to eq(40)
      end
    end

    # Every host colour is `data-color="host"`, so the colour alone cannot tell
    # two of them apart: the property is half of what a band is.
    context "with two host colours on one day" do
      let(:options) do
        { events: [
          { title: "A", starts_at: Time.zone.local(2026, 8, 20, 9), color: "--chart-4" },
          { title: "B", starts_at: Time.zone.local(2026, 8, 20, 10), color: "--chart-2" },
          { title: "C", starts_at: Time.zone.local(2026, 8, 20, 11), color: "--chart-4" }
        ] }
      end

      it "bands them apart and closes the gap only inside each", :aggregate_failures do
        ticks = day("2026-08-20").css(%(*[data-slot="event-calendar-day-tick"]))

        expect(ticks.map { |tick| tick["style"][/var\((--[^)]+)\)/, 1] }).to eq(%w[--chart-2 --chart-4 --chart-4])
        expect(ticks.map { |tick| tick["data-run-after"] }).to eq([ nil, "true", nil ])
        expect(ticks.map { |tick| tick["data-run-before"] }).to eq([ nil, nil, "true" ])
      end
    end

    context "when every day fits in its lanes" do
      it "keeps naming them from sm up" do
        expect(root["data-labelled"]).to eq("true")
      end
    end
  end

  # `Array(events)` splats a single Hash into its key/value pairs — the trap
  # `Event#wrap_assignees` carries a comment about, in the same family.
  describe "a single event" do
    subject(:calendar) do
      described_class.new(month: Date.new(2026, 8, 1),
                          events: { title: "Solo", starts_at: Date.new(2026, 8, 5) })
    end

    it "is a calendar with one event on it, not a TypeError" do
      render_inline(calendar)

      expect(day("2026-08-05")["aria-label"]).to end_with("1 event")
    end
  end

  # Five defects a review found, each of which renders a plausible page or a
  # 500 rather than anything a golden could catch.
  describe "inputs a host can plausibly hand it" do
    it "falls back to :auto for a reading it does not know", :aggregate_failures do
      expect(described_class.new(reading: :workLoad).reading).to eq(:auto)
      expect(described_class.new(reading: "workload").reading).to eq(:workload)
    end

    # `I18n.l`'s `%p` branch is guarded by `respond_to?(:hour)` and expands to
    # nothing, while `Date#strftime` fills `%-l:%M` from hour zero — so a Date
    # used to format as a confident midnight.
    context "when a time column is really a date column" do
      let(:options) do
        { selected: Date.new(2026, 8, 20),
          events: [ { title: "Task", starts_at: Time.zone.local(2026, 8, 20, 9, 30),
                      ends_at: Date.new(2026, 8, 20) } ] }
      end

      it "says nothing rather than midnight" do
        render_inline(calendar)

        expect(parts("item-description").map(&:text)).to eq([ "9:30 AM" ])
      end
    end

    # `Event.wrap` passes an already-built Event through, so a subclass can
    # carry a colour `COLORS.index` returns nil for.
    it "sorts an unknown colour last instead of raising" do
      exotic = Class.new(Shadcn::EventCalendar::Event) { def color = :teal }

      expect do
        render_inline(described_class.new(month: Date.new(2026, 8, 1), events: [
          exotic.new(title: "a", starts_at: Time.zone.local(2026, 8, 20, 9)),
          Shadcn::EventCalendar::Event.new(title: "b", starts_at: Time.zone.local(2026, 8, 20, 10), color: :blue)
        ]))
      end.not_to raise_error
    end

    # A `<button>` may not contain flow content, and the avatar group used to
    # be a `<div>`.
    it "keeps the workload day cell free of flow content" do
      render_inline(described_class.new(month: Date.new(2026, 8, 1), reading: :workload, events: [
        { title: "Job", starts_at: Time.zone.local(2026, 8, 3, 9),
          assignees: [ "Ada Lovelace", "Grace Hopper", "Alan Turing", "Marie Curie" ] }
      ]))

      expect(painted.at_css(%(*[data-day="2026-08-03"])).css("div")).to be_empty
    end
  end

  # The workload reading holds crews and titles the payload does not ship, so
  # the controller cannot redraw it and deliberately does not try. A URL is what
  # makes it navigable — and it serves the other readings too.
  describe "#month_url" do
    subject(:calendar) do
      described_class.new(month: Date.new(2026, 8, 1),
                          month_url: ->(date) { "/calendar/#{date.strftime('%Y-%m')}" })
    end

    before { render_inline(calendar) }

    def nav = painted.css(%(*[data-slot="event-calendar-nav"] a))

    it "makes the nav links to the months either side", :aggregate_failures do
      expect(nav.map { |link| link["href"] })
        .to eq([ "/calendar/2026-08", "/calendar/2026-07", "/calendar/2026-09" ])
    end

    # A link that also preventDefaults is a link that goes nowhere.
    it "leaves the controller's action off them" do
      expect(nav.map { |link| link["data-action"] }.compact).to be_empty
    end

    context "without one" do
      subject(:calendar) { described_class.new(month: Date.new(2026, 8, 1)) }

      it "keeps the nav as buttons the controller drives", :aggregate_failures do
        expect(nav).to be_empty
        expect(painted.css(%(*[data-slot="event-calendar-nav"] button[data-action])).size).to eq(3)
      end
    end
  end

  # The day view, when the server owns it. A link is the whole of what a host
  # needs to open a drawer or swap a frame — no listener, no URL built by hand,
  # and it works before the JavaScript has loaded.
  describe "#day_url" do
    subject(:calendar) do
      described_class.new(month: Date.new(2026, 8, 1),
                          day_url: ->(date) { "/day/#{date.iso8601}" },
                          day_attributes: { data: { turbo_frame: "day" } },
                          agenda_as: :"turbo-frame", agenda_attributes: { id: "day" })
    end

    before { render_inline(calendar) }

    it "makes every cell a link to its own day", :aggregate_failures do
      cell = day("2026-08-20")

      expect(cell.name).to eq("a")
      expect(cell["href"]).to eq("/day/2026-08-20")
      expect(cell["data-turbo-frame"]).to eq("day")
    end

    # A link that also selects in place would race its own navigation.
    it "leaves the controller's action off the cells" do
      expect(painted.css(%(*[data-slot="event-calendar-day"][data-action]))).to be_empty
    end

    it "keeps the grid semantics a button had", :aggregate_failures do
      cell = day("2026-08-20")

      expect(cell["role"]).to eq("gridcell")
      expect(cell["tabindex"]).to eq("-1")
      expect(day("2026-08-12")["aria-selected"]).to eq("true")
    end

    # `agenda_as:` is how the agenda becomes the thing a day link swaps without
    # this gem naming Turbo anywhere.
    it "lets the agenda be the frame", :aggregate_failures do
      agenda = painted.at_css(%(*[data-slot="event-calendar-agenda"]))

      expect(agenda.name).to eq("turbo-frame")
      expect(agenda["id"]).to eq("day")
    end

    # The live region exists because the agenda changes under a pointer that
    # never left the grid; a frame swap is a navigation and Turbo announces it.
    it "hands the agenda over to the server", :aggregate_failures do
      agenda = painted.at_css(%(*[data-slot="event-calendar-agenda"]))

      expect(agenda["aria-live"]).to be_nil
      expect(painted.css(%([data-shadcn--event-calendar-target*="agenda"]))).to be_empty
    end

    # Off when the host has somewhere better for the day — and it is what the
    # Day tab will be made of, so it is turned off rather than deleted.
    context "with the agenda turned off" do
      subject(:calendar) do
        described_class.new(month: Date.new(2026, 8, 1), agenda: false,
                            day_url: ->(date) { "/day/#{date.iso8601}" })
      end

      it "renders no day view of its own", :aggregate_failures do
        expect(painted.at_css(%(*[data-slot="event-calendar-agenda"]))).to be_nil
        expect(painted.at_css(%(*[data-slot="event-calendar-grid"]))).not_to be_nil
      end
    end

    context "without one" do
      subject(:calendar) { described_class.new(month: Date.new(2026, 8, 1)) }

      it "keeps the cells buttons the controller drives", :aggregate_failures do
        expect(day("2026-08-20").name).to eq("button")
        expect(day("2026-08-20")["data-action"]).to eq("click->shadcn--event-calendar#select")
        expect(painted.at_css(%(*[data-slot="event-calendar-agenda"]))["aria-live"]).to eq("polite")
      end
    end
  end

  describe "#max_events" do
    it "clamps to what the lanes and the cell height can express", :aggregate_failures do
      expect(described_class.new(max_events: 99).max_events).to eq(6)
      expect(described_class.new(max_events: 0).max_events).to eq(1)
    end
  end

  # Two contracts the controller reads at `connect()`. Nothing else in the suite
  # sees them: rename a slot and the server still renders a correct month, the
  # snapshot still matches the code that produced it, and only pressing › finds
  # out. `stimulus_contract_spec` checks actions, targets and values — not what
  # a target's contents have to contain.
  describe "the prototypes the controller clones" do
    before { render_inline(described_class.new(month: Date.new(2026, 8, 1))) }

    let(:template) { Nokogiri::HTML5.fragment(fragment.at_css("template").inner_html) }

    it "holds every shape a re-render needs", :aggregate_failures do
      %w[event-calendar-week event-calendar-event event-calendar-day-ticks
         event-calendar-day-tick event-calendar-day-more].each do |name|
        expect(template.at_css(%(*[data-slot="#{name}"]))).not_to be_nil, "no #{name} in the template"
      end
    end

    # The chip is cloned and then stripped down, never built up, so the shape
    # in the template has to be the timed one — an all-day chip renders neither
    # a dot nor a time, and a child that was never there cannot be cloned.
    it "holds a timed chip, which is the one with every child", :aggregate_failures do
      chip = template.at_css(%(*[data-slot="event-calendar-event"]))

      expect(chip.at_css(%(*[data-slot="event-calendar-event-dot"]))).not_to be_nil
      expect(chip.at_css(%(*[data-slot="event-calendar-event-time"]))).not_to be_nil
    end

    it "holds an agenda row of each kind, because a clone cannot change its tag" do
      rows = template.css(%(*[data-slot="event-calendar-agenda-row"]))

      expect(rows.map(&:name)).to eq(%w[div a])
    end

    it "holds a week with no events in it" do
      week = template.at_css(%(*[data-slot="event-calendar-week"]))

      expect(week.css(%(*[data-slot="event-calendar-event"]))).to be_empty
    end

    # The row is cloned and stripped, like the chip, so every part the server
    # row can have is in both prototypes — empty, for the clone to fill.
    it "holds every part a row can say, in both kinds of row", :aggregate_failures do
      template.css(%(*[data-slot="event-calendar-agenda-row"])).each do |row|
        %w[event-calendar-agenda-subtitle event-calendar-agenda-done event-calendar-agenda-attachment
           event-calendar-agenda-description event-calendar-agenda-avatars avatar-image avatar-group-count].each do |name|
          expect(row.at_css(%(*[data-slot="#{name}"]))).not_to be_nil, "no #{name} in the #{row.name} row"
        end
        expect(row.css("[data-slot=avatar-badge]").map { |badge| badge["data-status"] }).to eq(%w[done pending])
        expect(row.at_css("[data-slot=event-calendar-agenda-subtitle]").text).to eq("")
      end
    end
  end

  # Four bugs a review found, all of the same shape: the server renders a
  # month correctly and the *prototype* it hands the controller is wrong, so
  # nothing is visible until somebody presses a button. None of them could fail
  # a golden, because a golden is the HTML the code produces.
  # The hours reading places a job by its clock, and an all-day one has no
  # clock to be placed by — so it is the whole day, on top. Both halves are
  # asserted because both are the feature: `--for` is the width, `--lane` is
  # the position, and a bar that spans the day but sits at the bottom would
  # pass an assertion about either one alone.
  describe "a host colour" do
    let(:events) do
      [ { title: "Service", starts_at: Time.zone.local(2026, 8, 5, 9), color: "--chart-2", url: "/e/1" },
        { title: "Survey", starts_at: Time.zone.local(2026, 8, 5, 11), color: :blue, url: "/e/2" } ]
    end
    let(:set) { "--event-color:var(--chart-2);--event-ink:var(--foreground);" }

    def calendar_for(**options)
      render_inline(described_class.new(month: Date.new(2026, 8, 1), selected: Date.new(2026, 8, 5),
                                        day_url: ->(day) { "/d/#{day}" }, events:, **options))
    end

    it "sets the mark and leaves the ink neutral, on the chip and the row", :aggregate_failures do
      calendar_for(reading: :weekly, window: (7..19))

      host = [ parts("event-calendar-day-item").first, parts("event-calendar-agenda-item").first ]
      expect(host.map { |node| node["data-color"] }).to all(eq("host"))
      expect(host.map { |node| node["style"] }).to all(include(set))
    end

    it "writes no style for a fixed colour" do
      calendar_for(reading: :weekly, window: (7..19))

      expect(parts("event-calendar-agenda-item").last["style"]).to be_nil
    end

    it "sets it on the hours bar, ahead of the position", :aggregate_failures do
      calendar_for(reading: :hours, window: (7..19), shape: :bars)

      bars = parts("event-calendar-day-bar")
      expect(bars.first["style"]).to start_with(set).and include("--at:")
      expect(bars.last["style"]).to start_with("--at:")
    end

    it "sets it on the workload chip when grouped by event", :aggregate_failures do
      calendar_for(reading: :workload, group: :events)

      chips = parts("event-calendar-day-item")
      expect(chips.map { |chip| chip["data-color"] }).to include("host", "blue")
      expect(chips.find { |chip| chip["data-color"] == "host" }["style"]).to eq(set)
      expect(chips.find { |chip| chip["data-color"] == "blue" }["style"]).to be_nil
    end

    it "sets it on the month's bar and tick", :aggregate_failures do
      calendar_for(reading: :events)

      expect(parts("event-calendar-event").first["style"]).to start_with(set).and include("grid-column")
      expect(parts("event-calendar-event").last["style"]).to start_with("grid-column")
    end
  end

  describe "an all-day event in the hours reading" do
    subject(:bars) do
      render_inline(described_class.new(
        month: Date.new(2026, 8, 1), reading: :hours, window: (0..24), shape: :bars,
        events: [ { title: "Timed", starts_at: Time.zone.local(2026, 8, 20, 9) },
                  { title: "Holiday", starts_at: Date.new(2026, 8, 20) } ]
      ))
      page.all("[data-slot=event-calendar-day][data-day='2026-08-20'] [data-slot=event-calendar-day-bar]")
    end

    it "runs the whole width of the day" do
      expect(bars.first[:style]).to include("--at:0.0%", "--for:100.0%")
    end

    # The test is what the chip *occupies*, not what the event is flagged — so
    # the case that matters is the middle day of a *timed* job that crosses
    # days, where the two answers differ. The all-day one proves nothing: both
    # tests agree on it.
    #
    # Asserted as the class rather than the style, because `--for` is written on
    # every chip either way. An example that read the style passed for as long
    # as the bug existed.
    it "is as wide as the window on a day it covers whole", :aggregate_failures do
      render_inline(described_class.new(
        month: Date.new(2026, 8, 1), reading: :hours, window: (0..24), shape: :chips,
        events: [ { title: "Fit-out", starts_at: Time.zone.local(2026, 8, 19, 9),
                    ends_at: Time.zone.local(2026, 8, 21, 17) } ]
      ))
      middle = page.first("[data-slot=event-calendar-day][data-day='2026-08-20'] " \
                          "[data-slot=event-calendar-day-item]")

      expect(middle[:class].split).to include("w-(--for)")
      expect(middle[:class].split).not_to include("w-auto")
    end

    # The other branch, and the only way to reach it: the packer floors every
    # interval to the room a chip needs, so a chip falls back to its own text
    # only where the *window* clips it below that floor.
    it "is as wide as its own text where the window clips it short" do
      render_inline(described_class.new(
        month: Date.new(2026, 8, 1), reading: :hours, window: (7..19), shape: :chips,
        events: [ { title: "Late callout", starts_at: Time.zone.local(2026, 8, 20, 18, 40),
                    ends_at: Time.zone.local(2026, 8, 20, 23) } ]
      ))
      clipped = page.first("[data-slot=event-calendar-day][data-day='2026-08-20'] " \
                           "[data-slot=event-calendar-day-item]")

      expect(clipped[:class].split).to include("w-auto")
    end

    it "takes the top lane, above what has a clock", :aggregate_failures do
      expect(bars.first[:style]).to include("--lane:calc(0 *")
      expect(bars.last[:title]).to start_with("9:00 AM")
      expect(bars.last[:style]).to include("--lane:calc(1 *")
    end
  end

  # A job that crosses days is one bar per day in this reading, and each one is
  # clipped to the day it is drawn on — the hours axis has no way to say
  # "continues tomorrow", so what it says instead is where the work was that
  # day. The middle days are the whole axis for the same reason an all-day job
  # is: there is no hour to point at.
  describe "a multi-day job in the hours reading" do
    subject(:spans) do
      render_inline(described_class.new(
        month: Date.new(2026, 8, 1), reading: :hours, window: (0..24), shape: :bars,
        events: [ { title: "Fit-out", starts_at: Time.zone.local(2026, 8, 4, 9),
                    ends_at: Time.zone.local(2026, 8, 6, 17) } ]
      ))
      (4..6).map do |day|
        page.first("[data-slot=event-calendar-day][data-day='2026-08-0#{day}'] " \
                   "[data-slot=event-calendar-day-bar]")[:style]
      end
    end

    it "starts the first day at its clock and runs to midnight" do
      expect(spans.first).to include("--at:37.5%", "--for:62.5%")
    end

    it "gives a middle day the whole axis" do
      expect(spans[1]).to include("--at:0.0%", "--for:100.0%")
    end

    it "ends the last day at its clock" do
      expect(spans.last).to include("--at:0.0%", "--for:70.833%")
    end
  end

  # A chip is drawn on every day a job covers, and it used to read the job's
  # *first* clock on all of them — "9:00 AM" on the third day of a three-day
  # fit-out, a time nothing happened at. What a day wants to know is when the
  # work is on it.
  describe "a job that crosses days, in a workload cell" do
    subject(:chips) do
      render_inline(described_class.new(
        month: Date.new(2026, 8, 1), reading: :workload, group: :events,
        events: [ { title: "Fit-out", starts_at: Time.zone.local(2026, 8, 6, 9),
                    ends_at: Time.zone.local(2026, 8, 8, 17) } ]
      ))
      (6..8).map do |day|
        page.first("[data-slot=event-calendar-day][data-day='2026-08-0#{day}'] " \
                   "[data-slot=event-calendar-day-item]")
      end
    end

    it "reads the clock that belongs to each day" do
      expect(chips.map { |chip| chip.first("[data-slot=event-calendar-day-time]").text })
        .to eq([ "9:00 AM", "All day", "→ 5:00 PM" ])
    end

    # The same two attributes the events reading's bars have always used, so
    # the flat edge means the same thing in both.
    it "says which side it runs off", :aggregate_failures do
      expect(chips.map { |chip| chip["data-continues-before"] }).to eq([ nil, "true", "true" ])
      expect(chips.map { |chip| chip["data-continues-after"] }).to eq([ "true", "true", nil ])
    end

    # Because the flat edge cannot be seen in a stacked cell, and the rail
    # cannot say how long — so the span says it, the way the agenda does.
    it "carries the whole span on every day of it" do
      expect(chips.map { |chip| chip.first("[data-slot=event-calendar-day-span]").text })
        .to all(eq("Aug 06 – Aug 08"))
    end
  end

  # The first band's rows are held open across a week so a crossing job starts
  # at the same row in every cell. A day with no crossing job is not part of any
  # band, though, and reserving there bought an empty row and nothing else — a
  # Monday with eleven jobs and no fit-out opened on a gap.
  describe "a held row in a workload cell" do
    subject(:cells) do
      render_inline(described_class.new(
        month: Date.new(2026, 8, 1), reading: :workload, group: :events, week_starts_on: 1,
        events: [ { title: "Depot closed", starts_at: Date.new(2026, 8, 6) },
                  { title: "Fit-out", starts_at: Date.new(2026, 8, 4), ends_at: Date.new(2026, 8, 7) },
                  { title: "Standup", starts_at: Time.zone.local(2026, 8, 3, 9) } ]
      ))
      ->(day) { page.first("[data-slot=event-calendar-day][data-day='2026-08-0#{day}']") }
    end

    it "holds one where a crossing job needs the row above it" do
      expect(cells.call(4).all("[data-slot=event-calendar-day-held]", visible: :all).size).to eq(1)
    end

    it "holds none on a day with nothing to align" do
      expect(cells.call(3).all("[data-slot=event-calendar-day-held]", visible: :all)).to be_empty
    end
  end

  # The day the toolbar's period switch asks for, and what the agenda was
  # always going to become. It inherits the hours reading because a day is
  # where that axis finally has room — the same twenty-four hours that were a
  # twenty-eighth of a page in a month are the whole width here.
  describe "the daily reading" do
    def day(showing)
      render_inline(described_class.new(
        month: Date.new(2026, 8, 1), selected: Date.new(2026, 8, 4), reading: :daily,
        showing:, window: (7..19),
        events: [ { title: "Fit-out", starts_at: Time.zone.local(2026, 8, 4, 9) },
                  { title: "Stock take", starts_at: Date.new(2026, 8, 4) } ]
      ))
      page
    end

    def option_values(showing)
      day(showing).all("[data-slot=dropdown-menu-radio-item]", visible: :all).map { |item| item["data-value"] }
    end

    # Below `lg` the axis is wider than a phone and the grid scrolls sideways,
    # and nothing in it takes focus: without a tab stop of its own, the hours
    # past the edge need a pointer.
    it "makes the scrolling timeline a named region the keyboard can reach", :aggregate_failures do
      grid = day(:both).find("[data-slot=event-calendar-grid]")

      expect(grid["tabindex"]).to eq("0")
      expect(grid["role"]).to eq("region")
      expect(grid["aria-label"]).to eq("Hours of the day")
      expect(grid["class"].split).to include("focus-visible:ring-[3px]", "focus-visible:ring-ring/50")
    end

    # The Italian is the dummy app's, `test/dummy/config/locales/it.yml`.
    it "names the region in the host's language" do
      expect(I18n.with_locale(:it) { day(:axis) }.find("[data-slot=event-calendar-grid]")["aria-label"])
        .to eq("Ore del giorno")
    end

    # The shape is `Hours`'s and this inherits it, so a `shape:` a host passed
    # was being *drawn* and could not be changed — the panel showed the period,
    # the halves and the grouping, and never it. It belongs exactly where the
    # panel's own rule puts every other question: where there is something for
    # it to decide, which is wherever there is an axis.
    it "offers the shape exactly where there is an axis to shape", :aggregate_failures do
      expect(option_values(:both)).to include("chips", "bars")
      expect(option_values(:axis)).to include("chips", "bars")
      expect(option_values(:agenda)).not_to include("chips")
      expect(option_values(:agenda)).not_to include("bars")
    end

    it "titles itself with the day, not the month" do
      expect(day(:both).first("[data-slot=event-calendar-title]").text).to eq("Tuesday, August 4")
    end

    # Each half answers a question the other cannot: the axis says *when* the
    # day is busy and has no room for a name, the list says *what* each job is
    # and cannot show a gap.
    it "draws the halves it is asked for", :aggregate_failures do
      expect(day(:both)).to have_css("[data-slot=event-calendar-ruler]")
        .and have_css("[data-slot=event-calendar-agenda]")
      expect(day(:axis)).to have_no_css("[data-slot=event-calendar-agenda]", visible: :all)
      expect(day(:agenda)).to have_no_css("[data-slot=event-calendar-ruler]", visible: :all)
    end

    # The question a day actually gets asked is not "what is on" but "who is
    # where, and who is free at two" — so cut by operator it is a row each,
    # their jobs along the same hours, and the list below cut the same way and
    # in the same order, so whoever you found above you find again below.
    it "draws a row and a list section per operator, in one order", :aggregate_failures do
      render_inline(described_class.new(
        month: Date.new(2026, 8, 1), selected: Date.new(2026, 8, 4), reading: :daily,
        group: :assignees, window: (7..19),
        events: [ { title: "Fit-out", starts_at: Time.zone.local(2026, 8, 4, 9),
                    assignees: [ "Ada Lovelace", "Grace Hopper" ] },
                  { title: "Callout", starts_at: Time.zone.local(2026, 8, 4, 14),
                    assignees: [ "Ada Lovelace" ] } ]
      ))

      expect(page.all("[data-slot=event-calendar-resource]").map { _1.text[/[A-Z][a-z]+ [A-Z][a-z]+/] })
        .to eq([ "Ada Lovelace", "Grace Hopper" ])
      expect(page.all("[data-slot=event-calendar-agenda-title]").map { _1.text[/[A-Z][a-z]+ [A-Z][a-z]+/] })
        .to eq([ "Ada Lovelace", "Grace Hopper" ])
    end

    # A job with two people on it is on both their rows, because both are on it.
    it "puts a shared job on every row it belongs to" do
      render_inline(described_class.new(
        month: Date.new(2026, 8, 1), selected: Date.new(2026, 8, 4), reading: :daily,
        group: :assignees, showing: :axis, window: (7..19),
        events: [ { title: "Fit-out", starts_at: Time.zone.local(2026, 8, 4, 9),
                    assignees: [ "Ada Lovelace", "Grace Hopper" ] } ]
      ))

      expect(page.all("[data-slot=event-calendar-day-item]").size).to eq(2)
    end

    it "steps a day at a time, not a month" do
      expect(day(:both).first("[aria-label='Go to the Previous Day']")).to be_present
    end
  end

  # `**attributes` is `{...props}`: `id:`, `title:`, `href:` and the rest reach
  # the element untouched, which is the whole point of the bag. But a keyword a
  # *reading* owns, arriving at one that does not, was forwarded the same way —
  # so `reading: :auto, group: :events` rendered `group="events"`, an attribute
  # HTML has no idea what to do with.
  describe "a keyword meant for another reading" do
    subject(:root) do
      render_inline(described_class.new(
        month: Date.new(2026, 8, 1), reading: :auto, events: [],
        group: :events, show_all: true, group_url: ->(cut) { cut }, id: "cal", title: "A month"
      ))
      page.first("[data-slot=event-calendar]")
    end

    it "is namespaced rather than left as markup HTML cannot read", :aggregate_failures do
      expect(root["data-event-calendar-group"]).to eq("events")
      expect(root["group"]).to be_nil
    end

    # A `#<Proc>` in an attribute is noise with no reader.
    it "drops one whose value is a callback" do
      expect(root["data-event-calendar-group-url"]).to be_nil
    end

    # The bag still is the bag.
    it "leaves an ordinary prop alone", :aggregate_failures do
      expect(root["id"]).to eq("cal")
      expect(root["title"]).to eq("A month")
    end
  end

  describe "what the controller is handed" do
    let(:template) { Nokogiri::HTML5.fragment(fragment.at_css("template").inner_html) }

    # `#more` returns nothing when the calendar is not labelled, and the
    # prototype used to go through it — so a dense month shipped no "+N" and
    # the first navigation onto a month that overflowed threw on a null clone.
    context "when the month is too dense to name its events" do
      let(:options) { { events: forty_on_one_day } }

      before { render_inline(calendar) }

      it "still holds the shape a labelled month will need", :aggregate_failures do
        expect(root["data-labelled"]).to be_nil
        expect(template.at_css(%(*[data-slot="event-calendar-day-more"]))).not_to be_nil
      end
    end

    context "with the workload reading" do
      subject(:calendar) do
        described_class.new(month: Date.new(2026, 8, 1), reading: :workload, events: [
          { title: "Boiler service", starts_at: Time.zone.local(2026, 8, 1, 9),
            assignees: [ "Ada Lovelace" ] }
        ])
      end

      before { render_inline(calendar) }

      # It used to hand over a blank cell, because it handed one over at all:
      # the prototypes template shipped on every reading and this example
      # asserted the workload one carried nobody's name. Now the reading the
      # server draws whole ships neither the template nor the events, which is
      # 34 KB of a workload page that its own controller returned before
      # reading — and the strongest version of what this example was checking.
      it "hands the controller nothing to draw with", :aggregate_failures do
        expect(fragment.at_css("template")).to be_nil
        expect(root["data-shadcn--event-calendar-events-value"]).to be_nil
      end

      # The controller re-derived this from density alone and stamped
      # `data-labelled` on a workload month, running both readings at once.
      it "tells the controller which reading it is" do
        expect(root["data-shadcn--event-calendar-reading-value"]).to eq("workload")
      end
    end
  end

  describe "the events that cross to the controller" do
    let(:options) do
      { events: [ { title: "Meeting", starts_at: Time.zone.local(2026, 8, 20, 10, 30), color: :blue } ] }
    end
    let(:crossed) { JSON.parse(root["data-shadcn--event-calendar-events-value"]).first }

    before { render_inline(calendar) }


    # The controller formats no times at all — `shadcn/dates.js` stops at dates
    # on purpose — so every one of them has to arrive already written.
    it "carries the time already formatted by I18n" do
      expect(crossed["time"]).to eq("10:30 AM")
    end

    it "carries the day it starts on as an ISO date" do
      expect(crossed["from"]).to eq("2026-08-20")
    end

    # Every key is paid for once per event, and a dense month is two thousand of
    # them. What can be worked out is left out, and `eventsValueChanged` fills
    # it back in on the far side.
    it "leaves out what the controller can work out", :aggregate_failures do
      expect(crossed).not_to have_key("to")
      expect(crossed).not_to have_key("meta")
      expect(crossed).not_to have_key("allDay")
      expect(crossed).not_to have_key("url")
    end

    # The array's own order is the packing order; `dayOrder` is the one a single
    # day is read in. The controller needs both and can derive neither.
    it "carries the reading order a day is listed in" do
      expect(crossed).to have_key("dayOrder")
    end

    # The fields an event can say are paid for only by the events that say
    # them: a host passing none of them ships the payload it always did.
    it "adds nothing for an event that says no more than it did" do
      expect(crossed.keys).to match_array(%w[dayOrder title color from time])
    end

    context "with an event whose host labels the flags and a status" do
      let(:options) do
        { events: [ { title: "Service", starts_at: Time.zone.local(2026, 8, 20, 9),
                      done: { label: "Service completed" }, attachment: { label: "Has a report" },
                      assignees: [ { name: "Grace Hopper", status: :done, label: "Grace signed" } ] } ] }
      end

      it "carries the labels beside the flags", :aggregate_failures do
        expect(crossed.values_at("done", "doneLabel", "attachment", "attachmentLabel"))
          .to eq([ true, "Service completed", true, "Has a report" ])
        expect(crossed["assignees"])
          .to eq([ { "name" => "Grace Hopper", "initials" => "GH", "status" => "done", "label" => "Grace signed" } ])
      end
    end

    context "with an event that says everything" do
      let(:options) do
        { events: [ { title: "Service", starts_at: Time.zone.local(2026, 8, 20, 9), color: "--chart-2",
                      url: "/e/1", subtitle: "Via Roma 12", description: "Flue check", done: true,
                      attachment: true,
                      assignees: [ "Ada Lovelace", { name: "Grace Hopper", image: "/g.png", status: :pending } ],
                      attributes: { data: { turbo_frame: "event", action: "shadcn--dialog#open" },
                                    aria: { describedby: "note" }, class: %w[ring-2 ring-ring],
                                    href: "/elsewhere", "data-slot": "x", hidden: false } } ] }
      end

      it "carries exactly the keys it said" do
        expect(crossed.keys).to match_array(%w[dayOrder title color from time url colorProperty subtitle
                                               description done attachment assignees attributes])
      end

      it "carries the fields as the row draws them", :aggregate_failures do
        expect(crossed.values_at("color", "colorProperty", "subtitle", "description", "done", "attachment"))
          .to eq([ "host", "--chart-2", "Via Roma 12", "Flue check", true, true ])
        expect(crossed["assignees"]).to eq([
          { "name" => "Ada Lovelace", "initials" => "AL" },
          { "name" => "Grace Hopper", "initials" => "GH", "image" => "/g.png", "status" => "pending" }
        ])
      end

      # Flat, the way `tag` writes `data:` and `aria:` — the controller sets
      # attributes, it does not know Rails' nesting. What the row owns stays
      # the row's, as it does on the server.
      it "carries the attributes flat, without the ones the row owns" do
        expect(crossed["attributes"]).to eq(
          "data-action" => "shadcn--dialog#open", "data-turbo-frame" => "event",
          "aria-describedby" => "note", "class" => "ring-2 ring-ring"
        )
      end
    end

    # `setAttribute` throws on a name the browser rejects, and one throw is the
    # whole redraw. The server's row escapes such a name rather than dropping
    # it, so the payload carries it escaped the same way and the two agree.
    context "with an attribute name no element can carry" do
      let(:options) do
        { selected: Date.new(2026, 8, 20),
          events: [ { title: "Service", starts_at: Time.zone.local(2026, 8, 20, 9), url: "/e/1",
                      attributes: { "on click" => "x", "data-ok" => "1" } } ] }
      end

      it "carries the name as the server's row writes it", :aggregate_failures do
        expect(crossed["attributes"]).to eq("on_click" => "x", "data-ok" => "1")
        expect(parts("event-calendar-agenda-row").first["on_click"]).to eq("x")
      end
    end

    # With `day_url:` the agenda is the server's and no row is ever built in
    # the browser, so nothing only a row reads is worth shipping. The colour
    # still crosses: the bars and the marks are still redrawn.
    context "when the server owns the agenda" do
      let(:options) do
        { day_url: ->(day) { "/d/#{day}" },
          events: [ { title: "Service", starts_at: Time.zone.local(2026, 8, 20, 9), color: "--chart-2",
                      url: "/e/1", subtitle: "Via Roma 12", done: true, assignees: [ "Ada Lovelace" ],
                      attributes: { data: { turbo_frame: "event" } } } ] }
      end

      it "carries only what the month itself draws" do
        expect(crossed.keys).to match_array(%w[dayOrder title color from time url colorProperty])
      end
    end
  end

  # A move dispatches the host's own id, and an event has none unless the host
  # gave it one. These are the two halves of that: the identity travelling into
  # the DOM, and the render refusing to go on without it.
  describe "#movable" do
    let(:events) do
      [ { id: "a", title: "Conference", starts_at: Date.new(2026, 8, 19), ends_at: Date.new(2026, 8, 21) },
        { id: "b", title: "Standup", starts_at: Time.zone.local(2026, 8, 20, 9, 0) } ]
    end

    # Three siblings rather than a nest, because the middle one raises in `.new`:
    # a `before` that renders, shared with it, would take the error outside the
    # example's own block and fail it there.
    context "with an id on every event" do
      let(:options) { { events:, selected: Date.new(2026, 8, 20), movable: true } }

      before { render_inline(calendar) }

      it "names the event on every bar and every agenda row", :aggregate_failures do
        expect(parts("event-calendar-event").map { |bar| bar["data-event-id"] }).to eq(%w[a b])
        expect(parts("event-calendar-agenda-item").map { |row| row["data-event-id"] }).to eq(%w[a b])
      end

      it "offers a grip on every bar and a tab stop on every row", :aggregate_failures do
        expect(parts("event-calendar-event-grip").size).to eq(parts("event-calendar-event").size)
        expect(parts("event-calendar-agenda-item").map { |row| row["tabindex"] }).to all(eq("0"))
        expect(parts("event-calendar-agenda-mark").map { |mark| mark["class"] })
          .to all(include("cursor-grab"))
      end

      it "crosses the switch to the controller" do
        expect(painted.at_css("[data-slot=event-calendar]")["data-shadcn--event-calendar-movable-value"])
          .to eq("true")
      end
    end

    # The `<li>` was the tab stop and the `<a>` inside it another: two stops
    # for one row, and Enter on the outer one did nothing. With a url the link
    # is the one stop — Enter is the link's, Space still picks the row up.
    context "with an event that has a url" do
      let(:options) do
        { events: [ events.first.merge(url: "/e/a"), events.last ], selected: Date.new(2026, 8, 20),
          movable: true }
      end

      before { render_inline(calendar) }

      it "makes the link the row's one tab stop", :aggregate_failures do
        linked, plain = parts("event-calendar-agenda-item").to_a
        expect(linked["tabindex"]).to be_nil
        expect(linked.at_css("a[href='/e/a']")).not_to be_nil
        expect(plain["tabindex"]).to eq("0")
      end
    end

    context "with an event carrying no id" do
      let(:options) do
        { events: [ { title: "Nameless", starts_at: Date.new(2026, 8, 20) } ], movable: true }
      end

      it "says which event, rather than moving nothing" do
        expect { described_class.new(month: Date.new(2026, 8, 1), **options) }
          .to raise_error(ArgumentError, /Nameless/)
      end
    end

    context "without movable" do
      let(:options) { { events:, selected: Date.new(2026, 8, 20) } }

      before { render_inline(calendar) }

      it "writes no identity at all" do
        expect(parts("event-calendar-event").map { |bar| bar["data-event-id"] }).to all(be_nil)
      end

      it "offers nothing to take hold of", :aggregate_failures do
        expect(parts("event-calendar-event-grip")).to be_empty
        expect(parts("event-calendar-agenda-item").map { |row| row["tabindex"] }).to all(be_nil)
        expect(parts("event-calendar-agenda-mark").map { |mark| mark["class"] }.join)
          .not_to include("cursor-grab")
      end
    end
  end

  describe "the weekly reading" do
    let(:options) do
      { reading: :weekly, selected: Date.new(2026, 8, 5), window: (7..19),
        events: [ { title: "Fit-out", starts_at: Time.zone.local(2026, 8, 5, 9) } ] }
    end

    before { render_inline(calendar) }

    it "hands over to its own class" do
      expect(described_class.new(month: Date.new(2026, 8, 1), **options))
        .to be_a(Shadcn::EventCalendar::Weekly::Component)
    end

    it "draws the seven days of the week holding the selection", :aggregate_failures do
      expect(parts("event-calendar-day").size).to eq(7)
      expect(parts("event-calendar-day").map { |cell| cell["data-day"] }.first).to eq("2026-08-03")
      expect(parts("event-calendar-day").map { |cell| cell["role"] }).to all(eq("listitem"))
    end

    it "titles itself with the span, not the month" do
      expect(parts("event-calendar-title").first.text).to eq("3 – 9 August 2026")
    end

    it "asks how to show the week, offering rows and the timeline", :aggregate_failures do
      labels = painted.css("[data-slot=dropdown-menu-label]").map(&:text)
      views = painted.css("[data-slot=dropdown-menu-radio-item]").map { |item| item["data-value"] }

      expect(labels).to include("Show the week as")
      expect(views).to include("rows", "hours")
      expect(views).not_to include("grid")
    end

    it "checks the timeline and says so on the trigger", :aggregate_failures do
      checked = painted.css("[data-slot=dropdown-menu-radio-item][data-state=checked]")
                       .map { |item| item["data-value"] }

      expect(checked).to include("weekly", "hours")
      expect(parts("dropdown-menu-trigger").first.text.squish).to eq("Weekly · Timeline · Chips")
    end

    context "with a week that crosses a month" do
      let(:options) { { reading: :weekly, selected: Date.new(2026, 8, 31), window: (7..19) } }

      it "says both months" do
        expect(parts("event-calendar-title").first.text).to eq("31 August – 6 September 2026")
      end
    end

    # The one span where saying the year once is wrong: written only at the
    # end, it puts 28 December in the year that follows it.
    context "with a week that crosses a year" do
      subject(:calendar) { described_class.new(month: Date.new(2026, 12, 1), **options) }

      let(:options) { { reading: :weekly, selected: Date.new(2026, 12, 31), window: (7..19) } }

      it "says both years" do
        expect(parts("event-calendar-title").first.text).to eq("28 December 2026 – 3 January 2027")
      end
    end

    context "with a selection the month does not contain" do
      let(:options) { { reading: :weekly, selected: Date.new(2026, 9, 20), window: (7..19) } }

      it "falls back to the first week of the grid rather than raising" do
        expect(parts("event-calendar-day").map { |cell| cell["data-day"] }.first)
          .to eq("2026-07-27")
      end
    end
  end

  # The week drawn as the month's rows: the workload reading's row for each of
  # the seven days, asked for with `arrangement: :rows`. The timeline stays what
  # `reading: :weekly` alone draws.
  describe "the weekly reading, as rows" do
    let(:fit_out) do
      { title: "Fit-out", starts_at: Time.zone.local(2026, 8, 5, 9), assignees: [ "Ada Lovelace" ] }
    end
    let(:options) do
      { reading: :weekly, arrangement: :rows, selected: Date.new(2026, 8, 5), events: [ fit_out ] }
    end

    def render_with(**changed)
      render_inline(described_class.new(month: Date.new(2026, 8, 1), **options, **changed))
    end

    def root = painted.at_css("[data-slot=event-calendar]")

    def days = parts("event-calendar-day").map { |cell| cell["data-day"] }

    it "hands over to its own class, and only for rows", :aggregate_failures do
      expect(described_class.new(month: Date.new(2026, 8, 1), **options))
        .to be_a(Shadcn::EventCalendar::WeeklyRows::Component)
      expect(described_class.new(month: Date.new(2026, 8, 1), **options, arrangement: :auto))
        .to be_a(Shadcn::EventCalendar::Weekly::Component)
      expect(described_class.new(month: Date.new(2026, 8, 1), **options, arrangement: :bogus))
        .to be_a(Shadcn::EventCalendar::Weekly::Component)
    end

    # A host never names the subclass, but nothing stops one: built directly,
    # it must still be the rows rather than handing itself back to the
    # timeline because `reading: :weekly` alone means the timeline.
    it "stays itself when built directly", :aggregate_failures do
      expect(Shadcn::EventCalendar::WeeklyRows::Component.new(month: Date.new(2026, 8, 1), reading: :weekly))
        .to be_a(Shadcn::EventCalendar::WeeklyRows::Component)
      expect(Shadcn::EventCalendar::WeeklyRows::Component.new(month: Date.new(2026, 8, 1), reading: :weekly,
                                                              arrangement: :auto))
        .to be_a(Shadcn::EventCalendar::WeeklyRows::Component)
    end

    # A host flipping the view off `params` hands over a string.
    it "takes the arrangement as a string" do
      expect(described_class.new(month: Date.new(2026, 8, 1), **options, arrangement: "rows"))
        .to be_a(Shadcn::EventCalendar::WeeklyRows::Component)
    end

    it "draws the seven days as rows, forced at every width", :aggregate_failures do
      render_with

      expect(days).to eq(%w[2026-08-03 2026-08-04 2026-08-05 2026-08-06 2026-08-07 2026-08-08 2026-08-09])
      expect(parts("event-calendar-day").map { |cell| cell["role"] }).to all(eq("listitem"))
      expect(root["data-arrangement"]).to eq("rows")
      expect(parts("event-calendar-weekdays")).to be_empty
      expect(parts("event-calendar-ruler")).to be_empty
    end

    it "titles itself with the span and checks rows on the panel", :aggregate_failures do
      render_with

      expect(parts("event-calendar-title").first.text).to eq("3 – 9 August 2026")
      expect(parts("dropdown-menu-trigger").first.text.squish).to eq("Weekly · Rows · By event")
    end

    it "groups by event by default" do
      render_with

      expect(parts("event-calendar-day-item").size).to eq(1)
    end

    it "groups by assignee when asked" do
      render_with(group: :assignees)

      expect(parts("event-calendar-day-assignee").first.text).to include("Ada Lovelace")
    end

    it "steps a week through month_url" do
      render_with(month_url: ->(date) { "/m/#{date.iso8601}" })

      expect(painted.at_css("[aria-label='Go to the Next Week']")["href"]).to eq("/m/2026-08-12")
    end

    it "keeps the day list under the week, with the event's link", :aggregate_failures do
      render_with(day_url: ->(day) { "/d/#{day}" }, events: [ fit_out.merge(url: "/e/1") ])

      expect(parts("event-calendar-agenda")).not_to be_empty
      expect(parts("event-calendar-agenda-row").first["href"]).to eq("/e/1")
    end

    # The timeline's keywords on a rows week: a host flipping one param keeps
    # the others, and they must neither raise nor leak onto the element.
    #
    # They take the path every unread reading keyword takes: namespaced into a
    # `data-event-calendar-*` attribute, and a callable dropped rather than
    # stringified into a `#<Proc>`.
    it "ignores the timeline's keywords", :aggregate_failures do
      expect { render_with(window: (7..19), shape: :bars, shape_url: ->(form) { form }) }.not_to raise_error

      expect(root["data-event-calendar-window"]).to eq("7..19")
      expect(root["data-event-calendar-shape"]).to eq("bars")
      expect(root.attributes.keys).not_to include("window", "shape", "shape_url", "data-event-calendar-shape-url")
    end

    # The panel's hooks are the readings' own business, private on the base
    # class, and a week that made them public put them in a host's API.
    it "keeps the panel's hooks private, as the week's timeline and the day do", :aggregate_failures do
      hooks = %i[period cell_role view_choices view_heading]
      calendars = [ { reading: :weekly, arrangement: :rows }, { reading: :weekly }, { reading: :daily } ]

      calendars.each do |reading|
        calendar = described_class.new(month: Date.new(2026, 8, 1), **reading)
        expect(hooks.select { |hook| calendar.respond_to?(hook) }).to be_empty, reading.inspect
      end
    end

    it "draws a week that crosses a month with the next month's days outside", :aggregate_failures do
      render_with(selected: Date.new(2026, 8, 31))

      expect(days).to eq(%w[2026-08-31 2026-09-01 2026-09-02 2026-09-03 2026-09-04 2026-09-05 2026-09-06])
      expect(parts("event-calendar-day").to_a.last(6).map { |cell| cell["data-outside"] }).to all(eq("true"))
    end

    context "with a day busier than the cap" do
      let(:busy) do
        Array.new(5) { |index| { title: "Job #{index}", starts_at: Time.zone.local(2026, 8, 5, 8 + index) } }
      end

      it "shows three and counts the rest", :aggregate_failures do
        render_with(events: busy)

        expect(parts("event-calendar-day-item").size).to eq(3)
        expect(parts("event-calendar-day-rest").first.text).to eq("+2")
      end

      it "shows them all when asked" do
        render_with(events: busy, show_all: true)

        expect(parts("event-calendar-day-item").size).to eq(5)
      end
    end
  end

  # The panel used to decide the checked period with `(name == :daily) ==
  # daily?`, which says "there are two of these" in a comparison rather than in
  # a list. Asserted per reading, because the reading is what answers it.
  #
  # `data-state`, not `data-checked`: that is what `DropdownMenu::RadioItem`
  # writes, and a selector for the other one finds nothing and passes.
  describe "#period" do
    def checked_period(options)
      render_inline(described_class.new(month: Date.new(2026, 8, 1), **options))

      periods = described_class::PERIODS.map(&:to_s)
      painted.css("[data-slot=dropdown-menu-radio-item][data-state=checked]")
             .map { |item| item["data-value"] }
             .find { |value| periods.include?(value) }
    end

    # The readings that have a panel at all: it is a `reading_control`, and the
    # events reading declares none — a plain month renders no trigger and no
    # items, so asking it which period is checked has no answer rather than a
    # wrong one.
    it "is the month's for every monthly reading", :aggregate_failures do
      expect(checked_period(reading: :workload)).to eq("monthly")
      expect(checked_period(reading: :hours)).to eq("monthly")
    end

    it "is nothing at all for a reading with no panel" do
      expect(checked_period({})).to be_nil
    end

    it "is the day's for the daily reading" do
      expect(checked_period(reading: :daily)).to eq("daily")
    end

    it "is the week's for the weekly reading" do
      expect(checked_period(reading: :weekly)).to eq("weekly")
    end
  end

  # A phone is narrower than the controls a reading puts in the toolbar: the
  # day's measured 406px of nav against 342px of header at 390px wide, and the
  # page scrolled sideways. What keeps it inside is these classes, so they are
  # what is pinned; the widths themselves are measured in the browser, in
  # `spec/system/event_calendar_spec.rb`.
  # Where it sticks is the system spec's; this pins the three things it needs.
  describe "the weekday row" do
    before { render_inline(calendar) }

    it "sticks below the host's offset, over an opaque row, in a frame that is not a scroller",
       :aggregate_failures do
      expect(parts("event-calendar-weekdays").first["class"].split)
        .to include("sticky", "top-[var(--event-calendar-sticky-top,0px)]", "bg-background")
      frame = parts("event-calendar-grid").first["class"].split
      expect(frame).to include("overflow-clip")
      expect(frame).not_to include("overflow-hidden")
    end
  end

  describe "the toolbar on a narrow screen" do
    readings = {
      "the month" => {},
      "the month as rows" => { reading: :workload, arrangement: :rows },
      "the month's timeline" => { reading: :hours },
      "the week's timeline" => { reading: :weekly },
      "the week as rows" => { reading: :weekly, arrangement: :rows },
      "the day" => { reading: :daily }
    }

    readings.each do |name, reading|
      context "with #{name}" do
        let(:options) { reading.merge(selected: Date.new(2026, 8, 5)) }

        before { render_inline(calendar) }

        it "wraps the nav rather than letting it push past the header", :aggregate_failures do
          expect(parts("event-calendar-header").first["class"].split).to include("flex-wrap")
          expect(parts("event-calendar-nav").first["class"].split).to include("flex-wrap", "min-w-0")
          expect(parts("event-calendar-title").first["class"].split).to include("min-w-0")
        end
      end
    end

    context "with a view panel whose label is longer than the screen" do
      let(:options) { { reading: :daily, selected: Date.new(2026, 8, 5) } }

      before { render_inline(calendar) }

      # The one control whose width is a sentence the host translates.
      it "keeps the trigger inside the nav and ends its label in an ellipsis", :aggregate_failures do
        trigger = painted.at_css("[data-slot=event-calendar-nav] [data-slot=dropdown-menu-trigger]")

        expect(trigger["class"].split).to include("min-w-0", "max-w-full")
        expect(trigger.at_css("span")["class"].split).to include("truncate")
      end
    end
  end

  describe "what a chip says" do
    let(:options) do
      { reading: :weekly, selected: Date.new(2026, 8, 5), window: (7..19),
        events: [ { title: "Service", subtitle: "Rossi", description: "Bleed the radiators, spare filter",
                    done: true, attachment: true,
                    starts_at: Time.zone.local(2026, 8, 5, 9),
                    assignees: [ "Ada Lovelace", { name: "Grace Hopper", status: :done },
                                     { name: "Alan Turing", status: :pending } ] } ] }
    end

    before { render_inline(calendar) }

    it "draws the flags as icons with names", :aggregate_failures do
      expect(parts("event-calendar-day-done").first.text).to include("Done")
      expect(parts("event-calendar-day-attachment").first.text).to include("Has an attachment")
    end

    it "puts the subtitle on the title's line" do
      expect(parts("event-calendar-day-subtitle").first.text).to eq("Rossi")
    end

    it "keeps the description off the chip" do
      expect(painted.css("[data-slot=event-calendar-day-item]").text).not_to include("spare filter")
    end

    it "badges only the assignees with a status", :aggregate_failures do
      badges = painted.css("[data-slot=event-calendar-day-item] [data-slot=avatar-badge]")
      expect(badges.map { |badge| badge["data-status"] }).to eq(%w[done pending])
    end

    it "names each badge and tells pending from done by colour", :aggregate_failures do
      done, pending = painted.css("[data-slot=event-calendar-day-item] [data-slot=avatar-badge]").to_a
      expect(done.text).to include("Done")
      expect(done["class"]).not_to include("bg-muted-foreground")
      expect(pending.text).to include("Pending")
      expect(pending["class"].split).to include("bg-muted-foreground")
    end

    it "separates the title from the subtitle" do
      expect(parts("event-calendar-day-text").first.text).to include("Service Rossi")
    end

    context "when the host labels the flags and a status" do
      let(:options) do
        { reading: :weekly, selected: Date.new(2026, 8, 5), window: (7..19),
          events: [ { title: "Service", starts_at: Time.zone.local(2026, 8, 5, 9),
                      done: { label: "Service <b>completed</b>" }, attachment: { label: "Has a report" },
                      assignees: [ { name: "Grace Hopper", status: :done, label: "Grace signed" },
                                   { name: "Alan Turing", status: :pending } ] } ] }
      end

      # As text: the host's words are escaped like every other value of its.
      it "reads the host's words instead of the gem's", :aggregate_failures do
        expect(parts("event-calendar-day-done").first.at_css(".sr-only").text).to eq("Service <b>completed</b>")
        expect(parts("event-calendar-day-done").first.css("b")).to be_empty
        expect(parts("event-calendar-day-attachment").first.at_css(".sr-only").text).to eq("Has a report")
      end

      it "reads the host's word on a labelled badge and the gem's on the other", :aggregate_failures do
        labelled, plain = painted.css("[data-slot=event-calendar-day-item] [data-slot=avatar-badge]").to_a
        expect(labelled.text.strip).to eq("Grace signed")
        expect(plain.text.strip).to eq("Pending")
      end
    end

    context "when an assignee has a label and no status" do
      let(:options) do
        { reading: :weekly, selected: Date.new(2026, 8, 5), window: (7..19),
          events: [ { title: "Service", starts_at: Time.zone.local(2026, 8, 5, 9),
                      assignees: [ { name: "Grace Hopper", label: "Grace signed" } ] } ] }
      end

      it "draws no badge and says nothing", :aggregate_failures do
        expect(painted.css("[data-slot=avatar-badge]")).to be_empty
        expect(painted.text).not_to include("Grace signed")
      end
    end
  end

  describe "what a row says" do
    let(:attributes) { { data: { turbo_frame: "event", action: "shadcn--dialog#open" } } }
    let(:url) { "/e/1" }
    let(:options) do
      { reading: :weekly, selected: Date.new(2026, 8, 5), window: (7..19), day_url: ->(day) { "/days/#{day}" },
        events: [ { title: "Service", subtitle: "Rossi", description: "Bring the spare filter",
                    done: true, attachment: true, url:, attributes:,
                    starts_at: Time.zone.local(2026, 8, 5, 9),
                    assignees: [ "Ada Lovelace", { name: "Grace Hopper", status: :done } ] } ] }
    end

    before { render_inline(calendar) }

    it "reads everything out in full", :aggregate_failures do
      row = parts("event-calendar-agenda-row").first
      expect(row.at_css("[data-slot=event-calendar-agenda-subtitle]").text).to eq("Rossi")
      expect(row.at_css("[data-slot=event-calendar-agenda-description]").text).to eq("Bring the spare filter")
      expect(row.css("[data-slot=avatar]").size).to eq(2)
      expect(row.css("[data-slot=avatar-badge]").map { |badge| badge["data-status"] }).to eq([ "done" ])
      expect(row.css("[data-slot=event-calendar-agenda-done], [data-slot=event-calendar-agenda-attachment]").size).to eq(2)
    end

    context "when the host labels the flags and a status" do
      let(:options) do
        { reading: :weekly, selected: Date.new(2026, 8, 5), window: (7..19), day_url: ->(day) { "/days/#{day}" },
          events: [ { title: "Service", starts_at: Time.zone.local(2026, 8, 5, 9), url:,
                      done: { label: "Service completed" }, attachment: { label: "Has a report" },
                      assignees: [ { name: "Grace Hopper", status: :done, label: "Grace signed" } ] } ] }
      end

      it "reads the host's words in the row too", :aggregate_failures do
        row = parts("event-calendar-agenda-row").first
        expect(row.at_css("[data-slot=event-calendar-agenda-done] .sr-only").text).to eq("Service completed")
        expect(row.at_css("[data-slot=event-calendar-agenda-attachment] .sr-only").text).to eq("Has a report")
        expect(row.at_css("[data-slot=avatar-badge]").text.strip).to eq("Grace signed")
      end
    end

    it "reads the gem's words when the host gives none", :aggregate_failures do
      row = parts("event-calendar-agenda-row").first
      expect(row.at_css("[data-slot=event-calendar-agenda-done] .sr-only").text).to eq("Done")
      expect(row.at_css("[data-slot=event-calendar-agenda-attachment] .sr-only").text).to eq("Has an attachment")
      expect(row.at_css("[data-slot=avatar-badge]").text.strip).to eq("Done")
    end

    it "puts the host's attributes on the link", :aggregate_failures do
      link = parts("event-calendar-agenda-row").first
      expect(link.name).to eq("a")
      expect(link["data-turbo-frame"]).to eq("event")
      expect(link["data-action"]).to include("shadcn--dialog#open")
    end

    context "when the host tries to replace what the row owns" do
      let(:attributes) { { href: "/elsewhere", "data-slot": "x", class: "ring-2" } }

      it "keeps its own href and slot, and joins classes" do
        link = parts("event-calendar-agenda-row").first
        expect([ link["href"], link["data-slot"], link["class"].include?("ring-2") ])
          .to eq([ "/e/1", "event-calendar-agenda-row", true ])
      end
    end

    # The class goes through the pipeline every caller class does, so a Hash
    # means what it means on `Badge::Component.new(class: { … })` rather than
    # being written out as its own `inspect`.
    context "when the host's class is a Hash" do
      let(:attributes) { { class: { "ring-2" => true, "ring-ring" => false } } }

      it "keeps the true keys and drops the false ones", :aggregate_failures do
        classes = parts("event-calendar-agenda-row").first["class"].split
        expect(classes).to include("ring-2")
        expect(classes).not_to include("ring-ring")
        expect(classes.grep(/[{}"=>]/)).to be_empty
      end
    end

    # `as:` and `size:` are Item's arguments rather than attributes, so a host
    # hash that carries them would otherwise reach the constructor.
    context "when the host names Item's own arguments" do
      let(:attributes) { { as: :button, size: :default } }

      it "keeps the row a small link" do
        link = parts("event-calendar-agenda-row").first
        expect([ link.name, link["data-size"] ]).to eq([ "a", "sm" ])
      end
    end

    context "when there is no url to link to" do
      let(:url) { nil }

      it "drops attributes it has no link to put them on" do
        expect(painted.css("[data-turbo-frame]")).to be_empty
      end
    end
  end
end
