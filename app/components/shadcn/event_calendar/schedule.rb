# frozen_string_literal: true

module Shadcn
  module EventCalendar
    # A month's events, placed on its grid.
    #
    # This is the part of FullCalendar that is neither markup nor a browser:
    # `DayGridEventRenderer` decides, for one week, which row of the cell each
    # event gets so that a three-day event is *one bar* instead of three chips.
    # It is interval packing over seven columns, and it is testable without a
    # browser — which is why it is a plain object like `Calendar::Month`, and
    # not a component.
    #
    # The grid itself is not recomputed here: `Calendar::Month` already builds
    # it, already reads `Date.beginning_of_week` from the host application, and
    # already knows which days are outside the month.
    class Schedule
      # One event as it appears in one week: where it starts, how far it runs,
      # and which lane it was given. A multi-week event yields one of these per
      # week it touches, each clipped to that week — which is what makes the
      # bar restart at Monday instead of running off the edge.
      Segment = Struct.new(:event, :column, :span, :lane, :continues_before, :continues_after,
                           keyword_init: true) do
        def columns = column..(column + span - 1)
        def covers_column?(index) = columns.cover?(index)
        def continues_before? = continues_before
        def continues_after? = continues_after
      end

      # Seven days and the bars laid over them.
      class Week
        attr_reader :days, :segments, :max_lanes

        def initialize(days:, segments:, max_lanes:)
          @days = days
          @segments = segments
          @max_lanes = max_lanes
        end

        def visible = segments.select { |segment| segment.lane <= max_lanes }

        # What the "+2" in a cell counts: the bars that were pushed past the
        # last lane the cell has room for, on that day specifically. A segment
        # spanning three days hides on all three, which is why this counts
        # per-column rather than per-event.
        def hidden_on(day)
          index = days.index(day) + 1

          segments.count { |segment| segment.lane > max_lanes && segment.covers_column?(index) }
        end
      end

      attr_reader :month, :events, :max_lanes

      def initialize(month:, events: nil, max_lanes: 3, default_color: :default)
        @month = month
        # Not `Array(events)`: a single event is a Hash, and `Array(hash)` is
        # its key/value pairs. `Event#wrap_assignees` carries a comment about
        # exactly this trap and this line fell into it anyway — a host passing
        # one event, or `record.events.first`, got a `TypeError` out of a
        # private collaborator.
        list = events.is_a?(Array) ? events : [ events ]
        @events = list.compact.map { |event| Event.wrap(event, default_color:) }.sort_by(&:sort_key)
        @max_lanes = max_lanes
      end

      def weeks
        @weeks ||= month.weeks.map do |days|
          Week.new(days:, segments: pack(days), max_lanes:)
        end
      end

      # Whether any cell anywhere in the month has to say "+2". The component
      # reserves a row for that line when it does, and does not when it does
      # not — a row of empty space under every cell of every month is a high
      # price for a line that usually is not there.
      def overflow? = weeks.any? { |week| week.segments.any? { |segment| segment.lane > max_lanes } }

      # Everything happening on one day, in the order a person reads a day:
      # all-day first, then by the clock. Not derived from the segments — the
      # agenda and the phone's marks want the events, not their geometry.
      #
      # Indexed rather than filtered per call. A room-booking calendar is two
      # thousand events over forty-two cells, and every cell asks; scanning the
      # list once per cell is eighty-four thousand comparisons and forty-two
      # sorts, all of them repeated when the agenda asks again for the day it
      # is showing.
      def on(day) = by_day[day]

      # Who worked that day and how much, busiest first. Grouped by name
      # because two events carry two `Assignee` objects for the same person —
      # they come from a `map` over the host's records, not from an identity
      # map.
      def assignees_on(day)
        on(day).flat_map(&:assignees)
               .group_by(&:name)
               .map { |_, worked| [ worked.first, worked.size ] }
               # `name.to_s`: an `Assignee` a host built itself can still carry
               # a nil, and a nil in a sort key is a 500 rather than a bad
               # ordering.
               .sort_by { |assignee, count| [ -count, assignee.name.to_s ] }
      end

      # The most any one day holds. What the mark size is chosen against: a
      # calendar of ordinary days gets marks you can see, one of a hundred
      # bookings gets marks that fit.
      # Over the grid's own days, not over `by_day.values`. `by_day` is a Hash
      # with a writing default block, so any `on()` for a day outside the grid
      # added an entry — and `busiest` memoised whatever had been asked for by
      # then. Which reading the whole month rendered in depended on the order
      # the arguments of one `safe_join` happened to be evaluated in.
      def busiest = @busiest ||= month.days.map { |day| on(day).size }.max.to_i

      private

      def by_day
        # The index tiebreak makes the order deterministic: `sort_by` is not
        # stable and `day_sort_key` ends at the title, so two events differing
        # only in colour or url could come out either way — and `portable_events`
        # ranks them with the same tiebreak, so the two halves agree.
        @by_day ||= Hash.new { |days, day| days[day] = ordered_on(day) }
                        .tap { |days| month.days.each { |day| days[day] } }
      end

      def ordered_on(day)
        events.each_with_index
              .select { |event, _| event.covers?(day) }
              .sort_by { |event, index| [ *event.day_sort_key, index ] }
              .map(&:first)
      end

      def pack(days)
        span_of_week = days.first..days.last
        occupied = []

        events.select { |event| event.overlaps?(span_of_week) }.map do |event|
          from = [ event.start_date, days.first ].max
          to = [ event.end_date, days.last ].min
          columns = ((from - days.first).to_i + 1)..((to - days.first).to_i + 1)
          lane = free_lane(occupied, columns)
          (occupied[lane] ||= []) << columns

          Segment.new(event:, column: columns.first, span: columns.count, lane: lane + 1,
                      continues_before: event.start_date < days.first,
                      continues_after: event.end_date > days.last)
        end
      end

      # The lowest lane in which nothing already placed overlaps these columns.
      # Lowest rather than next-free is the whole point: it is what lets two
      # one-day events on opposite sides of the week share the top lane instead
      # of stacking the second one under the first.
      def free_lane(occupied, columns)
        lane = 0
        lane += 1 while occupied[lane]&.any? { |taken| taken.first <= columns.last && taken.last >= columns.first }
        lane
      end
    end
  end
end
