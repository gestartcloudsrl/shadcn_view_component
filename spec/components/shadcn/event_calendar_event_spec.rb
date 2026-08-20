# frozen_string_literal: true

require "spec_helper"

# What a host is allowed to pass, and what it means. The component never sees a
# hash: everything goes through here first, which is why the awkward inputs are
# asserted on the object rather than through rendered HTML.
RSpec.describe Shadcn::EventCalendar::Event do
  describe ".wrap" do
    it "builds one from a hash of symbol keys" do
      expect(described_class.wrap(title: "Standup", starts_at: Date.new(2026, 8, 20)))
        .to have_attributes(title: "Standup", start_date: Date.new(2026, 8, 20))
    end

    it "builds one from a hash of string keys" do
      expect(described_class.wrap("title" => "Standup", "starts_at" => Date.new(2026, 8, 20)))
        .to have_attributes(title: "Standup")
    end

    it "passes an Event through untouched" do
      event = described_class.new(title: "Standup", starts_at: Date.new(2026, 8, 20))

      expect(described_class.wrap(event)).to be(event)
    end
  end

  describe "#all_day?" do
    it "is inferred from a Date, which has no time of day to show" do
      expect(described_class.new(title: "Holiday", starts_at: Date.new(2026, 8, 20))).to be_all_day
    end

    it "is inferred from a Time, which has" do
      expect(described_class.new(title: "Standup", starts_at: Time.zone.local(2026, 8, 20, 9)))
        .not_to be_all_day
    end

    # The case inference cannot see: midnight is a real time and also how an
    # all-day event is often stored.
    it "takes the keyword over the inference" do
      expect(described_class.new(title: "Holiday", starts_at: Time.zone.local(2026, 8, 20), all_day: true))
        .to be_all_day
    end
  end

  describe "#end_date" do
    # FullCalendar's `end` is exclusive. This one is not, and the divergence is
    # deliberate — see features/event-calendar.md.
    it "is inclusive, so a three-day event lasts three days" do
      event = described_class.new(title: "Conference",
                                  starts_at: Date.new(2026, 8, 19), ends_at: Date.new(2026, 8, 21))

      expect(event.duration_days).to eq(3)
    end

    it "falls back to the start when no end was given" do
      event = described_class.new(title: "Standup", starts_at: Date.new(2026, 8, 20))

      expect(event.end_date).to eq(Date.new(2026, 8, 20))
    end

    # A data bug in the host's records, and a calendar that draws the day it
    # does know beats a page that 500s.
    it "clamps an end that falls before its start" do
      event = described_class.new(title: "Backwards",
                                  starts_at: Date.new(2026, 8, 20), ends_at: Date.new(2026, 8, 18))

      expect(event.end_date).to eq(Date.new(2026, 8, 20))
    end
  end

  describe "#color" do
    it "keeps a name from the palette" do
      expect(described_class.new(title: "x", starts_at: Date.current, color: :blue).color).to eq(:blue)
    end

    # Free-form colours cannot work: Tailwind never sees a class built at
    # runtime, and a hex has no answer for the dark palette.
    it "falls back to the default for a name that is not in it" do
      expect(described_class.new(title: "x", starts_at: Date.current, color: "#ff0000").color).to eq(:default)
    end
  end

  describe "#covers?" do
    subject(:event) do
      described_class.new(title: "Conference", starts_at: Date.new(2026, 8, 19), ends_at: Date.new(2026, 8, 21))
    end

    it "covers every day between its ends, inclusive", :aggregate_failures do
      expect(event).to be_covers(Date.new(2026, 8, 19))
      expect(event).to be_covers(Date.new(2026, 8, 20))
      expect(event).to be_covers(Date.new(2026, 8, 21))
    end

    it "covers neither the day before nor the day after", :aggregate_failures do
      expect(event).not_to be_covers(Date.new(2026, 8, 18))
      expect(event).not_to be_covers(Date.new(2026, 8, 22))
    end
  end
end
