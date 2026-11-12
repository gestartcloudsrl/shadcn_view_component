# frozen_string_literal: true

require "spec_helper"

# Every view a person can prefer, named once. It renders nothing, so it is
# asserted on directly — the same reason `Schedule` and `Calendar::Month` are
# plain objects.
RSpec.describe Shadcn::EventCalendar::Preferences do
  subject(:preferences) { described_class.new(shapes: %i[chips bars], agenda: true) }

  it "asks each view only its own questions" do
    expect(preferences.sets).to include(
      { period: :monthly, view: :grid, group: :events, max_chips: 3 },
      { period: :monthly, view: :hours, shape: :bars },
      { period: :weekly, view: :rows, group: :assignees, max_chips: :all },
      { period: :daily, showing: :agenda, group: :events },
      { period: :daily, showing: :axis, group: :events, shape: :chips }
    )
    expect(preferences.sets).not_to include(a_hash_including(period: :weekly, view: :grid))
  end

  # 32 = monthly grid 6 + rows 6 + hours 2, weekly rows 6 + hours 2, daily
  # both 4 + axis 4 + agenda 2: the chip limit has three answers (3, 5, all).
  it "counts every valid set once" do
    expect(preferences.sets.size).to eq(32)
    expect(preferences.sets.uniq.size).to eq(32)
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
  # every chip, a number one of the offered limits, anything else the default.
  it "reads the chip limit from what a form sends", :aggregate_failures do
    read = ->(value) { preferences.normalize(period: "monthly", view: "rows", max_chips: value)[:max_chips] }

    expect(read.call("5")).to eq(5)
    expect(read.call("all")).to eq(:all)
    expect(read.call("4")).to eq(3)
    expect(read.call(nil)).to eq(3)
  end

  it "asks the chip limit only where a view caps its chips" do
    expect(preferences.when(:max_chips)).to eq(%w[monthly:grid monthly:rows weekly:rows])
  end
end
