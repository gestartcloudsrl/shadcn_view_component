# frozen_string_literal: true

module Shadcn
  module EventCalendar
    # What makes a reading *a day*, whichever way it draws it: the date as its
    # title, a nav that steps one day, and the panel's "Show the day as". The
    # timeline (`Daily`) and the row (`DailyRows`) differ in what the day
    # looks like, and like the week's two they cannot share a parent — one is
    # an `Hours` reading and the other a `Workload` one — so it is a module
    # both include, as `Week` is.
    module Day
      private

      def period = :daily

      def view = :daily

      # A day's views are answers to "Show the day as", not a view question.
      def view_choices = []

      def cell_role = "listitem"

      # The title is a date rather than a month, because that is what changed.
      def title
        tag.div(I18n.l(selected, format: agenda_format),
                "data-slot": "event-calendar-title", class: EventCalendar::Component::TITLE_CLASS,
                role: "status", "aria-live": "polite")
      end

      # `‹` and `›` step a day here, not a month.
      def step_button(direction)
        target = selected + (direction == :previous ? -1 : 1)

        nav_button(target, size: :"icon-sm", action: EventCalendar::Component::STEP_ACTIONS.fetch(direction),
                   label: shadcn_t("event_calendar.#{direction}_day")) do
          render(Icon::Component.new(direction == :previous ? "chevron-left" : "chevron-right",
                                     class: EventCalendar::Component::CHEVRON_CLASS))
        end
      end

      # What a day can be shown as, from the host's `views:`: its row, then the
      # timeline's three ways (`Daily::Component::SHOWING`).
      def showing_choices
        offered = views.fetch(:daily)
        [ (:rows if offered.include?(:rows)), *(Daily::Component::SHOWING if offered.include?(:hours)) ].compact
      end

      # Not drawn with one answer, as the view question is not.
      def showing_items
        return if showing_choices.size <= 1

        safe_join([
          render(DropdownMenu::Label::Component.new) { shadcn_t("event_calendar.daily.label") },
          render(DropdownMenu::Separator::Component.new),
          render(DropdownMenu::RadioGroup::Component.new) do
            safe_join(showing_choices.map { |name| showing_item(name) })
          end
        ])
      end

      def showing_item(name)
        href = showing_url&.call(name)

        render(DropdownMenu::RadioItem::Component.new(
          value: name, checked: name == showing,
          **(href ? { as: :a, href: } : { "data-action": "click->shadcn--event-calendar#reshow" })
        )) { shadcn_t("event_calendar.daily.#{name}") }
      end
    end
  end
end
