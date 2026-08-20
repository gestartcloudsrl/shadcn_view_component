# frozen_string_literal: true

module Shadcn
  module EventCalendar
    # One entry on the calendar, normalised.
    #
    # A caller passes plain hashes — `{ title:, starts_at:, ends_at:, color: }` —
    # because that is what comes out of a `map` over their own records, and a
    # library cannot know what those records are called. `wrap` accepts an
    # already-built Event too, so a host that wants to subclass can.
    #
    # **`ends_at` is inclusive.** FullCalendar's is exclusive, which is correct
    # for arithmetic and wrong for everyone who has ever typed a date: an event
    # "19–21 August" is written here as `starts_at: 19th, ends_at: 21st`. That
    # divergence is deliberate and is the only one; it is in
    # [features/event-calendar.md](../../../../.claude/docs/features/event-calendar.md).
    class Event
      # Named rather than free-form, because an arbitrary colour would have to
      # arrive as a class or a hex and neither survives: Tailwind never sees a
      # string built at runtime, and a hex cannot answer to the dark palette.
      # Each name resolves to two custom properties in `Component::COLOR_TOKENS`.
      COLORS = %i[default blue green amber rose violet].freeze

      attr_reader :id, :title, :starts_at, :ends_at, :color, :url

      def self.wrap(value)
        return value if value.is_a?(Event)

        new(**value.to_h.symbolize_keys)
      end

      # @param all_day [Boolean, nil] inferred from `starts_at` when not given —
      #   a `Date` has no time of day to show, a `Time` has. An all-day `Time`
      #   at midnight is the case inference cannot see, so it takes the keyword.
      def initialize(title:, starts_at:, ends_at: nil, color: :default, url: nil, all_day: nil, id: nil)
        @id = id
        @title = title.to_s
        @starts_at = starts_at
        @ends_at = ends_at
        @all_day = all_day.nil? ? !starts_at.respond_to?(:hour) : !!all_day
        @color = COLORS.include?(color&.to_sym) ? color.to_sym : :default
        @url = url
      end

      def all_day? = @all_day

      def start_date = @start_date ||= starts_at.to_date

      # Clamped rather than raised on: an end before its start is a data bug in
      # the host's records, and a calendar that renders the day it does know
      # beats a page that 500s.
      def end_date = @end_date ||= [ (ends_at || starts_at).to_date, start_date ].max

      def duration_days = (end_date - start_date).to_i + 1

      def multi_day? = duration_days > 1

      def covers?(day) = day.between?(start_date, end_date)

      def overlaps?(range) = start_date <= range.last && end_date >= range.first

      # Longest first, then all-day before timed, then by clock, then by title
      # so the order is stable across renders. This is what decides which event
      # gets the top lane, and it is FullCalendar's own ordering: a bar that
      # crosses the week is more use above than below the one-day events it
      # would otherwise be interleaved with.
      def sort_key = [ -duration_days, all_day? ? 0 : 1, starts_at.to_time.to_i, title ]

      # Within one day the length no longer matters — what a person reads down
      # is the clock.
      def day_sort_key = [ all_day? ? 0 : 1, starts_at.to_time.to_i, title ]
    end
  end
end
