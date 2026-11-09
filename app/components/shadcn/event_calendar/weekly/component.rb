# frozen_string_literal: true

module Shadcn
  module EventCalendar
    module Weekly
      # A week is seven `Hours` rows over one window, so Tuesday at ten sits
      # directly above Thursday at ten. It is `Daily`'s sibling rather than its
      # subclass: what the two share is being a period that is not the month,
      # and `Daily`'s nav steps a day.
      class Component < Hours::Component
        def view = :weekly

        def period = :weekly

        def cell_role = "listitem"

        private

        # The week of the rendered grid that holds `selected`, falling back to
        # the first rather than raising: a host can pass a `selected` this month
        # does not contain, and `default_selection` answers the same question
        # for a day by taking the first of the month.
        def week
          @week ||= schedule.weeks.find { |candidate| candidate.days.include?(selected) } ||
                    schedule.weeks.first
        end

        def title
          tag.div(span_label,
                  "data-slot": "event-calendar-title", class: TITLE_CLASS,
                  role: "status", "aria-live": "polite")
        end

        # "3 – 9 August 2026", the month said twice when the week crosses one,
        # and the year too when it crosses that — the cases a fixture month
        # sitting inside a single month makes easy to forget.
        def span_label
          from = week.days.first
          to = week.days.last
          opening =
            if from.year != to.year then I18n.l(from, format: "%-d %B %Y")
            elsif from.month != to.month then I18n.l(from, format: "%-d %B")
            else from.strftime("%-d")
            end

          "#{opening} – #{I18n.l(to, format: '%-d %B %Y')}"
        end

        # `‹` and `›` step a week here, not a month.
        def step_button(direction)
          target = selected + (direction == :previous ? -7 : 7)

          nav_button(target, size: :"icon-sm", action: STEP_ACTIONS.fetch(direction),
                     label: shadcn_t("event_calendar.#{direction}_week")) do
            render(Icon::Component.new(direction == :previous ? "chevron-left" : "chevron-right",
                                       class: CHEVRON_CLASS))
          end
        end

        # Seven rows and the scale above them — no weekday strip and no
        # `role="grid"`, because seven stacked days are a list and the
        # seven-column geometry a grid role would report does not exist here.
        def grid
          tag.div(safe_join([ scale, week_rows ].compact),
                  "data-slot": "event-calendar-grid", class: FRAME_CLASS)
        end

        def week_rows
          cells = week.days.map do |day|
            day_cell(day, on_day: schedule.on(day), assignees: schedule.assignees_on(day), hidden: 0)
          end

          tag.div(safe_join(cells),
                  "data-slot": "event-calendar-weeks", class: WEEKS_CLASS,
                  role: "list", "aria-label": span_label)
        end
      end
    end
  end
end
