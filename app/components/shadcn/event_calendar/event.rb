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

      # Who is doing the thing — a name, or a name and a picture. An event can
      # take more than one, which is what the by-event grouping counts. Only the
      # workload reading reads them.
      Assignee = Struct.new(:name, :image) do
        def initials = name.to_s.split(/\s+/).first(2).filter_map { |part| part[0] }.join.upcase
      end

      attr_reader :id, :title, :starts_at, :ends_at, :color, :url, :assignees

      # `default_color:` is the calendar's own colour, standing where
      # FullCalendar puts an *event source's*: between the event and the
      # fallback. An already-built Event passes through untouched — it resolved
      # its colour when it was built, and a caller who constructed one meant it.
      def self.wrap(value, default_color: :default)
        return value if value.is_a?(Event)

        new(default_color:, **value.to_h.symbolize_keys)
      end

      # @param all_day [Boolean, nil] inferred from `starts_at` when not given —
      #   a `Date` has no time of day to show, a `Time` has. An all-day `Time`
      #   at midnight is the case inference cannot see, so it takes the keyword.
      def initialize(title:, starts_at:, ends_at: nil, color: nil, url: nil, all_day: nil,
                     id: nil, assignee: nil, assignees: nil, default_color: :default)
        @id = id
        @title = title.to_s
        @starts_at = starts_at
        @ends_at = ends_at
        @all_day = all_day.nil? ? !starts_at.respond_to?(:hour) : !!all_day
        # A name that is not in the palette falls back to the *calendar's*
        # colour rather than to grey: a typo in one row of a `map` should look
        # like the rest of that calendar, not like an uncategorised event.
        @color = COLORS.include?(color&.to_sym) ? color.to_sym : fallback_color(default_color)
        @url = url
        @assignees = wrap_assignees(assignees || assignee)
      end

      def all_day? = @all_day

      def fallback_color(name) = COLORS.include?(name&.to_sym) ? name.to_sym : :default
      private :fallback_color

      # `Array()` is not usable here: a single `{ name:, image: }` is a Hash, and
      # `Array(hash)` is its pairs rather than one element.
      def wrap_assignees(value)
        list = value.is_a?(Array) ? value : [ value ]

        list.filter_map { |one| wrap_assignee(one) }
      end
      private :wrap_assignees

      # A String is the common case — a name off a record. A Hash is the one
      # with a picture.
      #
      # A hash keyed anything but `:name` used to yield `Assignee.new(nil)`
      # silently, which drew an empty avatar and — once two operators tied on
      # count — raised `comparison of Array with Array failed` out of
      # `Schedule#assignees_on` and took the page with it. Loud where it can be
      # fixed and quiet where it cannot, which is the trade `Icon::Component`
      # makes for an unknown icon: a host mapping `full_name` finds out in
      # development, and production draws an unnamed face rather than a 500.
      def wrap_assignee(value)
        case value
        when nil, Assignee then value
        when String then Assignee.new(value.to_s, nil)
        else
          name, image = value.to_h.symbolize_keys.values_at(:name, :image)
          raise ArgumentError, "an assignee needs a :name, got #{value.inspect}" if name.blank? && Rails.env.local?

          Assignee.new(name.to_s, image)
        end
      end
      private :wrap_assignee

      def start_date = @start_date ||= starts_at.to_date

      # Clamped rather than raised on: an end before its start is a data bug in
      # the host's records, and a calendar that renders the day it does know
      # beats a page that 500s.
      def end_date = @end_date ||= [ (ends_at || starts_at).to_date, start_date ].max

      def duration_days = (end_date - start_date).to_i + 1

      def multi_day? = duration_days > 1

      def covers?(day) = day.between?(start_date, end_date)

      # All day *as far as this day is concerned*. A job flagged all-day is one
      # everywhere; a timed job that started yesterday and ends tomorrow is one
      # here, because there is no hour of this day it is not on.
      #
      # The chip's clock has always read it this way — a middle day says "All
      # day" — and the bands did not, so a job that said "All day" and crossed
      # days sat below one that said "All day" and did not.
      def all_day_on?(day) = all_day? || (start_date < day && end_date > day)

      def overlaps?(range) = start_date <= range.last && end_date >= range.first

      # All-day first, then longest, then by clock, then by title so the order
      # is stable across renders. This is what decides which event gets the top
      # lane.
      #
      # All-day leads because that is what an all-day event *is*: not a thing
      # that happens at a moment the grid can point at, but a fact about the
      # whole day, and a fact belongs above the schedule rather than interleaved
      # with it. FullCalendar says the same thing with a separate all-day row;
      # this port has one row of lanes, so it says it with the sort.
      #
      # Length used to lead, and it read fine until the two disagreed: a *timed*
      # event running three days took the top lane over a one-day holiday,
      # because three beats all-day when duration is compared first. Within
      # each of the two groups length still leads, for the reason it always
      # did — a bar that crosses the week is more use above than below the
      # one-day events it would otherwise be interleaved with.
      def sort_key = [ all_day? ? 0 : 1, -duration_days, starts_at.to_time.to_i, title ]

      # What a person reads down a cell, in three bands rather than two.
      #
      # A job that is all day *and* crosses days is the standing fact about that
      # day — the depot is shut, the crew is away on a fit-out — and it holds
      # true before and after it, so it goes above the facts that are only
      # today's. Then the single-day all-day ones. Then everything with a clock,
      # in clock order, because that is what a person reads a day by.
      #
      # Length does not sort within a band the way `sort_key` has it: inside one
      # day a five-day job and a two-day job are both simply on, and the clock
      # then the title keep the order stable across renders.
      def day_sort_key(day = nil) = [ day_band(day), day_moment, title ]

      # An all-day job is ranked by its date and a timed one by its clock, which
      # is not pedantry: `Date.new(2026, 8, 20)` and `Time.zone.local(2026, 8,
      # 20)` are the same midnight to a reader and two different integers to
      # `to_time`, one in the system zone and one in the app's. Two all-day jobs
      # on one day were ordered by which way their start had been *written*
      # rather than by their title.
      def day_moment = all_day? ? start_date.jd : starts_at.to_time.to_i
      private :day_moment

      def day_band(day = nil)
        return 2 unless day ? all_day_on?(day) : all_day?

        multi_day? ? 0 : 1
      end
      private :day_band
    end
  end
end
