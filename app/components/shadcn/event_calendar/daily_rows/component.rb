# frozen_string_literal: true

module Shadcn
  module EventCalendar
    module DailyRows
      # The day drawn as one of the week's rows: the date column, then the
      # day's chips in a strip ordered by time, grouped by event or by assignee,
      # with the count, the cap and its "+N", and *Show all* — and no clock.
      #
      # A host asks for it with `reading: :daily, showing: :rows`: "Rows" is
      # one more answer to the panel's "Show the day as", so a host's
      # `showing_url:` reaches it as it reaches the timeline's three. It is
      # offered only where `views:` names it for the day.
      #
      # What makes it a day is `Day`, shared with `Daily`; what the row looks
      # like is `Workload`'s, inherited untouched.
      class Component < Workload::Component
        include Day

        attr_reader :showing_url

        # Rows at every width, as the week's are. `showing:` is consumed here:
        # this class is what `:rows` means.
        def initialize(showing: :rows, showing_url: nil, **attributes)
          @showing_url = showing_url
          super(**attributes, arrangement: :rows)
        end

        def showing = :rows

        private

        def reading_label
          safe_join([ shadcn_t("event_calendar.daily.rows"), grouping_label ], " · ")
        end

        def reading_options = [ showing_items, grouping_items ].compact

        def preference_values = { period: :daily, showing: :rows, group:, max_chips: (show_all ? :all : preference_chip_count) }

        # The one row, a list of one as the week is a list of seven — no
        # weekday strip, which is a grid's heading.
        def grid
          cell = day_cell(selected, on_day: schedule.on(selected), assignees: schedule.assignees_on(selected), hidden: 0)

          tag.div(
            tag.div(cell, "data-slot": "event-calendar-weeks", class: WEEKS_CLASS,
                          role: "list", "aria-label": I18n.l(selected, format: agenda_format)),
            "data-slot": "event-calendar-grid", class: FRAME_CLASS
          )
        end
      end
    end
  end
end
