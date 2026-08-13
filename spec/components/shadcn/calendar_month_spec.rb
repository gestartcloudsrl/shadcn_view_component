# frozen_string_literal: true

require "spec_helper"

# The grid `react-day-picker` builds in JavaScript, built in Ruby instead. It
# renders nothing, so it can be asserted on directly — which is the reason it is
# a plain object.
RSpec.describe Shadcn::Calendar::Month do
  # August 2026 starts on a Saturday and ends on a Monday, so every edge of the
  # grid needs filling from a neighbouring month — the case a month starting on
  # the first day of a week would not exercise.
  subject(:month) { described_class.new(Date.new(2026, 8, 15), week_starts_on: 0) }

  it "runs from the first day of the week the month starts in", :aggregate_failures do
    expect(month.weeks.first.first).to eq(Date.new(2026, 7, 26))
    expect(month.weeks.first.first.wday).to eq(0)
  end

  it "runs to the last day of the week the month ends in" do
    expect(month.weeks.last.last).to eq(Date.new(2026, 9, 5))
  end

  it "gives every week seven days" do
    expect(month.weeks.map(&:size).uniq).to eq([ 7 ])
  end

  it "holds every day of the month itself" do
    expect(month.days).to include(*(Date.new(2026, 8, 1)..Date.new(2026, 8, 31)))
  end

  it "marks the days either side as outside", :aggregate_failures do
    expect(month).to be_outside(Date.new(2026, 7, 31))
    expect(month).not_to be_outside(Date.new(2026, 8, 1))
  end

  context "when the week starts on Monday" do
    subject(:month) { described_class.new(Date.new(2026, 8, 15), week_starts_on: 1) }

    it "shifts the grid by a day", :aggregate_failures do
      expect(month.weeks.first.first).to eq(Date.new(2026, 7, 27))
      expect(month.weekday_numbers).to eq([ 1, 2, 3, 4, 5, 6, 0 ])
    end
  end

  context "with fixed weeks" do
    subject(:month) { described_class.new(Date.new(2026, 2, 1), week_starts_on: 0, fixed_weeks: true) }

    # February 2026 starts on a Sunday and has 28 days, so it fits in four rows
    # exactly — the shortest grid a month can have, and the one a fixed height
    # has to pad the most.
    it "pads a short month out to six rows" do
      expect(month.weeks.size).to eq(6)
    end
  end

  context "without fixed weeks" do
    subject(:month) { described_class.new(Date.new(2026, 2, 1), week_starts_on: 0) }

    it "takes only the rows the month needs" do
      expect(month.weeks.size).to eq(4)
    end
  end

  describe "#number_of" do
    it "counts ISO weeks" do
      expect(month.number_of(month.weeks.first)).to eq(Date.new(2026, 7, 26).cweek)
    end
  end

  describe "#previous and #next" do
    it "step a month at a time, keeping the settings", :aggregate_failures do
      expect(month.previous.date).to eq(Date.new(2026, 7, 1))
      expect(month.next.date).to eq(Date.new(2026, 9, 1))
      expect(month.next.week_starts_on).to eq(0)
    end
  end

  describe "the default week start" do
    it "follows the application's own setting rather than a constant" do
      expect(described_class.new(Date.new(2026, 8, 15)).week_starts_on)
        .to eq(Date::DAYNAMES.index(Date.beginning_of_week.to_s.capitalize))
    end
  end
end
