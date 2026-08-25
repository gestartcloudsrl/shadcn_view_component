# frozen_string_literal: true

require "spec_helper"

# The part of FullCalendar that is neither markup nor a browser: deciding which
# row of a cell each event gets, so that a three-day event is one bar. It
# renders nothing, so it is asserted on directly — the same reason
# `Calendar::Month` is a plain object.
#
# The algorithm exists twice, here and in `event_calendar_controller.js`. These
# examples pin the Ruby half; `spec/system/event_calendar_spec.rb` is what
# compares the browser's answer against it.
RSpec.describe Shadcn::EventCalendar::Schedule do
  # August 2026 with a Monday start: the weeks are Jul 27–Aug 2, Aug 3–9,
  # Aug 10–16, Aug 17–23, Aug 24–30 and Aug 31–Sep 6. Every edge of the grid
  # needs filling, which is the case a month starting on a Monday would not
  # exercise.
  let(:month) { Shadcn::Calendar::Month.new(Date.new(2026, 8, 1), week_starts_on: 1) }

  def schedule(events, max_lanes: 3)
    described_class.new(month:, events:, max_lanes:)
  end

  def week_of(schedule, day) = schedule.weeks.find { |week| week.days.include?(day) }

  describe "#weeks" do
    it "gives one segment per event per week it touches" do
      one_day = schedule([ { title: "Standup", starts_at: Date.new(2026, 8, 20) } ])

      expect(one_day.weeks.sum { |week| week.segments.size }).to eq(1)
    end

    it "places a one-day event in the column its weekday sits in" do
      # Thursday, and the week starts on Monday.
      thursday = schedule([ { title: "Standup", starts_at: Date.new(2026, 8, 20) } ])
      segment = week_of(thursday, Date.new(2026, 8, 20)).segments.first

      expect(segment).to have_attributes(column: 4, span: 1, lane: 1)
    end

    it "spans a multi-day event across the columns it covers" do
      conference = schedule([
        { title: "Conference", starts_at: Date.new(2026, 8, 19), ends_at: Date.new(2026, 8, 21) }
      ])
      segment = week_of(conference, Date.new(2026, 8, 20)).segments.first

      expect(segment).to have_attributes(column: 3, span: 3)
    end

    context "when an event crosses a week boundary" do
      # Saturday to Tuesday, over the Sunday the grid breaks on.
      subject(:crossing) do
        schedule([ { title: "Trip", starts_at: Date.new(2026, 8, 8), ends_at: Date.new(2026, 8, 11) } ])
      end

      let(:first) { week_of(crossing, Date.new(2026, 8, 8)).segments.first }
      let(:second) { week_of(crossing, Date.new(2026, 8, 11)).segments.first }

      it "clips it into one segment per week", :aggregate_failures do
        expect(first).to have_attributes(column: 6, span: 2)
        expect(second).to have_attributes(column: 1, span: 2)
      end

      it "marks which end of each segment is a cut", :aggregate_failures do
        expect(first).to have_attributes(continues_before: false, continues_after: true)
        expect(second).to have_attributes(continues_before: true, continues_after: false)
      end
    end
  end

  describe "lane packing" do
    it "stacks events that share a day" do
      same_day = schedule([
        { title: "Standup", starts_at: Time.zone.local(2026, 8, 20, 9) },
        { title: "Lunch", starts_at: Time.zone.local(2026, 8, 20, 12) }
      ])

      expect(week_of(same_day, Date.new(2026, 8, 20)).segments.map(&:lane)).to eq([ 1, 2 ])
    end

    # The whole reason it is *lowest* free rather than next free: two events on
    # opposite sides of a week share the top row instead of stacking.
    it "reuses a lane for events that do not overlap" do
      apart = schedule([
        { title: "Monday", starts_at: Date.new(2026, 8, 17) },
        { title: "Friday", starts_at: Date.new(2026, 8, 21) }
      ])

      expect(week_of(apart, Date.new(2026, 8, 20)).segments.map(&:lane)).to eq([ 1, 1 ])
    end

    # An all-day event is not a thing that happens at a moment the grid can
    # point at, it is a fact about the whole day — so it belongs above the
    # schedule rather than interleaved with it. Length used to lead and this is
    # where the two disagree: three days of a *timed* event beat one day of a
    # holiday, and the holiday ended up underneath.
    it "gives the top lane to an all-day event over a longer timed one" do
      mixed = schedule([
        { title: "Trip", starts_at: Time.zone.local(2026, 8, 19, 9),
          ends_at: Time.zone.local(2026, 8, 21, 17) },
        { title: "Holiday", starts_at: Date.new(2026, 8, 20) }
      ])
      lanes = week_of(mixed, Date.new(2026, 8, 20)).segments.to_h { |s| [ s.event.title, s.lane ] }

      expect(lanes).to eq("Holiday" => 1, "Trip" => 2)
    end

    # `sort_key` puts the longest first *within* each of the two groups, so the
    # bar that crosses the week still gets the top row of the timed ones.
    it "gives the top lane to the longest event" do
      mixed = schedule([
        { title: "Standup", starts_at: Time.zone.local(2026, 8, 20, 9) },
        { title: "Conference", starts_at: Date.new(2026, 8, 19), ends_at: Date.new(2026, 8, 21) }
      ])
      lanes = week_of(mixed, Date.new(2026, 8, 20)).segments.to_h { |segment| [ segment.event.title, segment.lane ] }

      expect(lanes).to eq("Conference" => 1, "Standup" => 2)
    end
  end

  describe "overflow" do
    subject(:crowded) do
      schedule(4.times.map { |slot| { title: "Slot #{slot}", starts_at: Time.zone.local(2026, 8, 20, 9 + slot) } },
               max_lanes: 3)
    end

    let(:week) { week_of(crowded, Date.new(2026, 8, 20)) }

    it "shows only the lanes the cell has room for" do
      expect(week.visible.size).to eq(3)
    end

    it "counts what it hid, on the day it hid it", :aggregate_failures do
      expect(week.hidden_on(Date.new(2026, 8, 20))).to eq(1)
      expect(week.hidden_on(Date.new(2026, 8, 21))).to eq(0)
    end

    it "reports that the month needs a row for the count" do
      expect(crowded).to be_overflow
    end

    context "when everything fits" do
      subject(:roomy) { schedule([ { title: "Standup", starts_at: Date.new(2026, 8, 20) } ]) }

      it "does not ask for the row" do
        expect(roomy).not_to be_overflow
      end
    end
  end

  # `by_day` is a Hash with a writing default block, so asking about a day
  # outside the grid used to add an entry — and `busiest` memoised whatever had
  # been asked for by then. Which reading the month rendered in depended on
  # argument-evaluation order.
  # Ordering a cell is not enough to make a five-day job read as one band across
  # five cells. As soon as a second crossing job starts halfway through the
  # first, the first one's position moves on the day the second ends — so a job
  # needs a lane it *keeps*, and `#pack` already computes one for the grid's
  # bars.
  describe "#crossing_on" do
    subject(:overlapping) do
      schedule([
        { title: "A", starts_at: Date.new(2026, 8, 17), ends_at: Date.new(2026, 8, 19) },
        { title: "B", starts_at: Date.new(2026, 8, 18), ends_at: Date.new(2026, 8, 21) },
        { title: "Standup", starts_at: Time.zone.local(2026, 8, 20, 9) }
      ], max_lanes: 5)
    end

    def slots(day) = overlapping.crossing_on(Date.new(2026, 8, day)).map { |event| event&.title }

    it "keeps each job on the lane it holds all week", :aggregate_failures do
      expect(slots(18)).to eq(%w[B A])
      expect(slots(19)).to eq(%w[B A])
    end

    # The hole is the point: closing it up would move `A` on the one day `B`
    # is not there, which is the whole thing the lanes exist to stop.
    it "leaves a hole where a lane's job has not started" do
      expect(slots(17)).to eq([ nil, "A" ])
    end

    it "leaves out what does not cross days" do
      expect(slots(20)).to eq([ "B" ])
    end

    # `#pack` numbers lanes over *every* event in the week, so a job outside
    # this band holding a low lane used to leave a hole at the top of every cell
    # the crossing job appeared in — a lane nothing could ever fill, because its
    # holder never arrives here. Ranked among themselves, there is no hole to
    # keep for it.
    it "does not hold a lane for a job that is not in this band" do
      overlapped = schedule([
        { title: "Stock take", starts_at: Date.new(2026, 8, 19) },
        { title: "Standup", starts_at: Time.zone.local(2026, 8, 19, 9) },
        { title: "Fit-out", starts_at: Date.new(2026, 8, 18), ends_at: Date.new(2026, 8, 20) }
      ], max_lanes: 5)

      expect(overlapped.crossing_on(Date.new(2026, 8, 19)).map { |event| event&.title })
        .to eq([ "Fit-out" ])
    end

    # A timed job is banded by what it is on the day being drawn, not by its
    # flag: on the middle day of a fit-out there is no hour of that day it is
    # not on, and its own chip says "All day" there. The two used to disagree,
    # so a chip reading "All day" and crossing days sat below one reading "All
    # day" that did not.
    context "with a timed job that crosses days" do
      subject(:fit_out) do
        schedule([
          { title: "Fit-out", starts_at: Time.zone.local(2026, 8, 18, 9),
            ends_at: Time.zone.local(2026, 8, 20, 17) },
          { title: "Stock take", starts_at: Date.new(2026, 8, 19) }
        ], max_lanes: 5)
      end

      it "takes the band on a day it covers whole" do
        expect(fit_out.crossing_on(Date.new(2026, 8, 19)).map(&:title)).to eq(%w[Fit-out])
      end

      it "leads the cell there, above an all-day job of one day" do
        expect(fit_out.on(Date.new(2026, 8, 19)).map(&:title)).to eq(%w[Fit-out Stock\ take])
      end

      # Its first and last days are hours, not a fact about the day, so it
      # reads with the rest — which is where "→ 5:00 PM" belongs.
      it "leaves the band on the day it ends", :aggregate_failures do
        expect(fit_out.crossing_on(Date.new(2026, 8, 20))).to be_empty
        expect(fit_out.crossing_on(Date.new(2026, 8, 18))).to be_empty
      end
    end
  end

  describe "#busiest" do
    subject(:month_of_one) { schedule([ { title: "x", starts_at: Date.new(2026, 8, 5) } ]) }

    it "counts the grid's own days, whatever else has been asked about" do
      month_of_one.on(Date.new(2026, 10, 15))

      expect(month_of_one.busiest).to eq(1)
    end
  end

  describe "#on" do
    subject(:day) do
      schedule([
        { title: "Lunch", starts_at: Time.zone.local(2026, 8, 20, 12) },
        { title: "Conference", starts_at: Date.new(2026, 8, 19), ends_at: Date.new(2026, 8, 21) },
        { title: "Standup", starts_at: Time.zone.local(2026, 8, 20, 9) }
      ]).on(Date.new(2026, 8, 20))
    end

    # What the agenda reads down and what the phone's dots count: not the
    # packing order, which puts the longest first, but three bands.
    it "reads all-day first, then by time" do
      expect(day.map(&:title)).to eq(%w[Conference Standup Lunch])
    end

    # A job that is all day *and* crosses days is the standing fact about that
    # day — the depot is shut, the crew is away — and it holds before and after
    # it, so it reads above the facts that are only today's.
    it "puts a crossing all-day job above a one-day one" do
      banded = schedule([
        { title: "Holiday", starts_at: Date.new(2026, 8, 20) },
        { title: "Fit-out", starts_at: Date.new(2026, 8, 18), ends_at: Date.new(2026, 8, 22) },
        { title: "Standup", starts_at: Time.zone.local(2026, 8, 20, 9) }
      ])

      expect(banded.on(Date.new(2026, 8, 20)).map(&:title)).to eq(%w[Fit-out Holiday Standup])
    end

    # `Date.new(2026, 8, 20)` and `Time.zone.local(2026, 8, 20)` are the same
    # midnight to a reader and two different integers to `to_time`. Ranking an
    # all-day job by its date rather than its clock is what stops two of them
    # sorting by which way their start happened to be written.
    it "orders two all-day jobs by name, however their start was written" do
      same_day = schedule([
        { title: "Holiday", starts_at: Date.new(2026, 8, 20) },
        { title: "Audit", starts_at: Time.zone.local(2026, 8, 20), all_day: true }
      ])

      expect(same_day.on(Date.new(2026, 8, 20)).map(&:title)).to eq(%w[Audit Holiday])
    end

    it "includes an event whose middle day this is" do
      expect(day.map(&:title)).to include("Conference")
    end

    context "with a day nothing touches" do
      it "is empty" do
        expect(schedule([ { title: "Standup", starts_at: Date.new(2026, 8, 20) } ]).on(Date.new(2026, 8, 21)))
          .to be_empty
      end
    end
  end
end
