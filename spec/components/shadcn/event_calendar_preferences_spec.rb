# frozen_string_literal: true

require "spec_helper"

# Every view a person can prefer, named once. It renders nothing, so it is
# asserted on directly — the same reason `Schedule` and `Calendar::Month` are
# plain objects.
RSpec.describe Shadcn::EventCalendar::Preferences do
  subject(:preferences) { described_class.new(shapes: %i[chips bars], agenda: true) }

  it "asks each view only its own questions" do
    expect(preferences.sets).to include(
      { period: :monthly, view: :grid, group: :events },
      { period: :monthly, view: :hours, shape: :bars },
      { period: :weekly, view: :rows, group: :assignees },
      { period: :daily, showing: :agenda, group: :events },
      { period: :daily, showing: :axis, group: :events, shape: :chips }
    )
    expect(preferences.sets).not_to include(a_hash_including(period: :weekly, view: :grid))
  end

  # 20 = monthly grid 2 + rows 2 + hours 2, weekly rows 2 + hours 2, daily
  # both 4 + axis 4 + agenda 2. The chip limit is typed, so it multiplies
  # nothing: no set carries it.
  it "counts every valid set once, leaving the typed limit out", :aggregate_failures do
    expect(preferences.sets.size).to eq(20)
    expect(preferences.sets.uniq.size).to eq(20)
    expect(preferences.sets).to all(satisfy { |set| !set.key?(:max_chips) })
  end

  it "says which sets are asked the chip limit", :aggregate_failures do
    expect(preferences.sets.select { |set| preferences.asks?(:max_chips, set) })
      .to match_array(%i[events assignees].flat_map { |group|
        [ { period: :monthly, view: :grid, group: }, { period: :monthly, view: :rows, group: },
          { period: :weekly, view: :rows, group: } ]
      })
  end

  it "answers a question in a set, in question order" do
    expect(preferences.answer({ period: :weekly, view: :rows, group: :events }, :max_chips, 7).to_a)
      .to eq([ [ :period, :weekly ], [ :view, :rows ], [ :group, :events ], [ :max_chips, 7 ] ])
  end

  it "stops asking the shape when one is offered, and the list without an agenda", :aggregate_failures do
    narrow = described_class.new(shapes: %i[chips], agenda: false)

    expect(narrow.sets).to all(satisfy { |set| !set.key?(:shape) })
    expect(narrow.sets.filter_map { |set| set[:showing] }.uniq).to eq(%i[both axis])
  end

  it "keys a set in question order" do
    expect(described_class.key({ period: :weekly, view: :rows, group: :events, max_chips: 5 }))
      .to eq("preferences[period]=weekly&preferences[view]=rows&preferences[group]=events&preferences[max_chips]=5")
  end

  it "normalises what a reading is drawing", :aggregate_failures do
    expect(preferences.normalize(period: :weekly, view: :rows, group: :events, max_chips: 5, shape: :bars))
      .to eq(period: :weekly, view: :rows, group: :events, max_chips: 5)
    expect(preferences.normalize(period: :weekly, view: :grid)).to be_nil
  end

  it "says where each field is shown" do
    expect(preferences.when(:shape)).to eq(%w[monthly:hours weekly:hours daily:both daily:axis])
    expect(preferences.when(:view, :grid)).to eq(%w[monthly])
  end

  # The limit arrives as a string from a form or a host's stored set: "all" is
  # every chip, a whole number in the range is that many. Anything else is a
  # set that is not one, as an unknown period is — not quietly the default.
  it "reads the chip limit from what a form sends", :aggregate_failures do
    read = ->(value) { preferences.normalize(period: "monthly", view: "rows", max_chips: value)&.fetch(:max_chips) }

    expect(read.call("7")).to eq(7)
    expect(read.call(42)).to eq(42)
    expect(read.call("1")).to eq(1)
    expect(read.call("99")).to eq(99)
    expect(read.call("all")).to eq(:all)
    %w[0 100 -3 4.5 abc 7a].push("", 4.0).each { |bad| expect(read.call(bad)).to be_nil, bad.inspect }
  end

  it "takes the reading's default for a limit not given at all" do
    expect(preferences.normalize(period: "weekly", view: "rows")).to eq(period: :weekly, view: :rows, group: :events, max_chips: 3)
  end

  it "ignores a bad limit where the view does not ask it" do
    expect(preferences.normalize(period: "monthly", view: "hours", max_chips: "abc")).to eq(period: :monthly, view: :hours, shape: :chips)
  end

  it "publishes the range a typed limit is checked against" do
    expect(described_class::MAX_CHIPS_RANGE).to eq(1..99)
  end

  it "asks the chip limit only where a view caps its chips" do
    expect(preferences.when(:max_chips)).to eq(%w[monthly:grid monthly:rows weekly:rows])
  end
end
