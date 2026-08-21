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

    it "lists the selected day's events and nothing else" do
      expect(parts("event-calendar-agenda-event-title").map(&:text)).to eq(%w[Conference Meeting])
    end

    it "reads a timed event as a span of the clock" do
      expect(parts("event-calendar-agenda-meta").map(&:text).last).to eq("10:30 AM – 11:30 AM")
    end

    it "reads a multi-day event as a span of days" do
      expect(parts("event-calendar-agenda-meta").map(&:text).first).to eq("Aug 19 – Aug 21")
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

        expect(parts("event-calendar-agenda-meta").map(&:text)).to eq([ "9:30 AM" ])
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
  end

  # Four bugs a review found, all of the same shape: the server renders a
  # month correctly and the *prototype* it hands the controller is wrong, so
  # nothing is visible until somebody presses a button. None of them could fail
  # a golden, because a golden is the HTML the code produces.
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

      # `workload_cell` used to ignore the `on_day:` it was handed and ask the
      # schedule again, so `blank: true` blanked the count and nothing else.
      it "hands over a blank cell, not the first week's people", :aggregate_failures do
        expect(template.css(%(*[data-slot="event-calendar-day-assignee"]))).to be_empty
        expect(template.css(%(*[data-slot="event-calendar-day-item"]))).to be_empty
        expect(template.css(%(*[data-slot="event-calendar-day-count"]))).to be_empty
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
  end
end
