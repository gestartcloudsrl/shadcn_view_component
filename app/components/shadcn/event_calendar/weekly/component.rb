# frozen_string_literal: true

module Shadcn
  module EventCalendar
    module Weekly
      # A week is seven `Hours` rows over one window, so Tuesday at ten sits
      # directly above Thursday at ten. It is `Daily`'s sibling rather than its
      # subclass: what the two share is being a period that is not the month,
      # and `Daily`'s nav steps a day.
      #
      # What makes it a week is `Week`, shared with `WeeklyRows`; what is left
      # here is the timeline's own frame. Its view is the inherited `:hours`,
      # which is what the panel checks and what `view_url:` is handed.
      class Component < Hours::Component
        include Week

        private

        # Seven rows and the scale above them — no weekday strip and no
        # `role="grid"`.
        def grid
          tag.div(safe_join([ scale, week_rows ].compact),
                  "data-slot": "event-calendar-grid", class: FRAME_CLASS)
        end
      end
    end
  end
end
