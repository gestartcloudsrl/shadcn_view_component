# frozen_string_literal: true

module Shadcn
  module EventCalendar
    module WeeklyRows
      # The week drawn as the month's rows: the workload reading's row for each
      # of its seven days — the date column, then the day's chips in a strip
      # ordered by time, grouped by event or by assignee — with no clock axis.
      #
      # The timeline answers *when*; these answer *what is on, and whose*. A
      # host asks for them with `reading: :weekly, arrangement: :rows`, and
      # `reading: :weekly` alone is still the timeline, because the gem is
      # published and an existing call must keep drawing what it drew.
      #
      # What makes it a week is `Week`, shared with `Weekly`; everything a day
      # looks like is `Workload`'s, inherited untouched — the heat ramp scaled
      # against the month the week sits in, the cap of three and its "+N", and
      # *Show all*.
      class Component < Workload::Component
        include Week

        # Rows at every width: there is no grid to fall back to above `lg`,
        # so whatever arrangement was passed, this is the one drawn.
        def initialize(**attributes)
          super(**attributes, arrangement: :rows)
        end

        private

        # The seven rows alone — no weekday strip, which is a grid's heading,
        # and no scale, which is the timeline's.
        def grid
          tag.div(week_rows, "data-slot": "event-calendar-grid", class: FRAME_CLASS)
        end
      end
    end
  end
end
