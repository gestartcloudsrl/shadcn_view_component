# frozen_string_literal: true

require "spec_helper"

# Every view a person can prefer, named once. It renders nothing, so it is
# asserted on directly — the same reason `Schedule` and `Calendar::Month` are
# plain objects.
RSpec.describe Shadcn::EventCalendar::Preferences do
  subject(:preferences) { described_class.new(shapes: %i[chips bars], agenda: true) }

  it "asks each view only its own questions" do
    expect(preferences.sets).to include(
      { period: :monthly, view: :grid, group: :events, show_all: false },
      { period: :monthly, view: :hours, shape: :bars },
      { period: :weekly, view: :rows, group: :assignees, show_all: true },
      { period: :daily, showing: :agenda, group: :events },
      { period: :daily, showing: :axis, group: :events, shape: :chips }
    )
    expect(preferences.sets).not_to include(a_hash_including(period: :weekly, view: :grid))
  end

  # 26 = monthly grid 4 + rows 4 + hours 2, weekly rows 4 + hours 2, daily
  # both 4 + axis 4 + agenda 2.
  it "counts every valid set once" do
    expect(preferences.sets.size).to eq(26)
    expect(preferences.sets.uniq.size).to eq(26)
  end

  it "stops asking the shape when one is offered, and the list without an agenda", :aggregate_failures do
    narrow = described_class.new(shapes: %i[chips], agenda: false)

    expect(narrow.sets).to all(satisfy { |set| !set.key?(:shape) })
    expect(narrow.sets.filter_map { |set| set[:showing] }.uniq).to eq(%i[both axis])
  end

  it "keys a set in question order" do
    expect(described_class.key({ period: :weekly, view: :rows, group: :events, show_all: false }))
      .to eq("preferences[period]=weekly&preferences[view]=rows&preferences[group]=events&preferences[show_all]=false")
  end

  it "normalises what a reading is drawing", :aggregate_failures do
    expect(preferences.normalize(period: :weekly, view: :rows, group: :events, show_all: false, shape: :bars))
      .to eq(period: :weekly, view: :rows, group: :events, show_all: false)
    expect(preferences.normalize(period: :weekly, view: :grid)).to be_nil
  end

  it "says where each field is shown" do
    expect(preferences.when(:shape)).to eq(%w[monthly:hours weekly:hours daily:both daily:axis])
    expect(preferences.when(:view, :grid)).to eq(%w[monthly])
  end
end
