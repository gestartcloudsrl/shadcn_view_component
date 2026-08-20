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

      expect(day("2026-08-12")["aria-pressed"]).to eq("true")
    end

    context "when the month is not the one today falls in" do
      subject(:calendar) { described_class.new(month: Date.new(2026, 11, 1)) }

      it "is the first of the month" do
        render_inline(calendar)

        expect(day("2026-11-01")["aria-pressed"]).to eq("true")
      end
    end

    context "when the caller names one" do
      let(:options) { { selected: Date.new(2026, 8, 25) } }

      it "is the one the caller named" do
        render_inline(calendar)

        expect(day("2026-08-25")["aria-pressed"]).to eq("true")
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
      %w[event-calendar-week event-calendar-event event-calendar-day-dots
         event-calendar-day-dot event-calendar-day-more].each do |name|
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

  describe "the events that cross to the controller" do
    let(:options) do
      { events: [ { title: "Meeting", starts_at: Time.zone.local(2026, 8, 20, 10, 30), color: :blue } ] }
    end
    let(:crossed) { JSON.parse(root["data-shadcn--event-calendar-events-value"]).first }

    before { render_inline(calendar) }


    # The controller formats no times at all — `shadcn/dates.js` stops at dates
    # on purpose — so every one of them has to arrive already written.
    it "carries the time already formatted by I18n", :aggregate_failures do
      expect(crossed["time"]).to eq("10:30 AM")
      expect(crossed["meta"]).to eq("10:30 AM")
    end

    it "carries the day span as ISO dates", :aggregate_failures do
      expect(crossed["from"]).to eq("2026-08-20")
      expect(crossed["to"]).to eq("2026-08-20")
    end

    # The array's own order is the packing order; `dayOrder` is the one a single
    # day is read in. The controller needs both and can derive neither.
    it "carries the reading order a day is listed in" do
      expect(crossed).to have_key("dayOrder")
    end
  end
end
