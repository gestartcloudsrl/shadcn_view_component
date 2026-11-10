# frozen_string_literal: true

module Shadcn
  module EventCalendar
    # What makes a reading *a week*, whichever way it draws its days: which
    # week, the span it is titled with, a nav that steps seven days, and seven
    # stacked days rather than a grid. The timeline (`Weekly`) and the rows
    # (`WeeklyRows`) differ in what a day looks like, not in any of this, and
    # they cannot share a parent — one is an `Hours` reading and the other a
    # `Workload` one — so it is a module both include.
    module Week
      private

      def period = :weekly

      def cell_role = "listitem"

      # A week is drawn as rows or as the timeline. There is no grid: seven
      # narrow columns are what the rows were built to avoid.
      def view_choices = EventCalendar::Component::WEEK_VIEWS

      def view_heading = shadcn_t("event_calendar.view.week_label")

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
                "data-slot": "event-calendar-title", class: EventCalendar::Component::TITLE_CLASS,
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

        nav_button(target, size: :"icon-sm", action: EventCalendar::Component::STEP_ACTIONS.fetch(direction),
                   label: shadcn_t("event_calendar.#{direction}_week")) do
          render(Icon::Component.new(direction == :previous ? "chevron-left" : "chevron-right",
                                     class: EventCalendar::Component::CHEVRON_CLASS))
        end
      end

      # Seven stacked days are a `role="list"` and not a grid: the
      # seven-column geometry a grid role would report does not exist here.
      def week_rows
        cells = week.days.map do |day|
          day_cell(day, on_day: schedule.on(day), assignees: schedule.assignees_on(day), hidden: 0)
        end

        tag.div(safe_join(cells),
                "data-slot": "event-calendar-weeks", class: EventCalendar::Component::WEEKS_CLASS,
                role: "list", "aria-label": span_label)
      end
    end
  end
end
