# frozen_string_literal: true

module Shadcn
  module EventCalendar
    module Daily
      # One day rather than a month — the *Day* the toolbar's period switch asks
      # for, and what the agenda was always going to become.
      #
      # It inherits `Hours::Component` because a day is where its axis finally
      # has room: the same twenty-four hours that were a twenty-eighth of a page
      # in a month are the whole width here, so a fifteen-minute call is a mark
      # you can see rather than a floor of three pixels.
      #
      # What it shows is a choice, because the two halves answer different
      # questions and a reader wants one or the other or both: the axis says
      # *when the day is busy* and cannot write a name; the agenda says *what
      # each job is* and cannot show a gap.
      class Component < Hours::Component
        SHOWING = %i[axis agenda both].freeze

        # One row, not forty-two, so the frame's month rules have nothing to do
        # here — and the cell grows with its lanes rather than being told a
        # height, because a day with thirty jobs is as tall as it is.
        TOKENS = "[&_[data-slot=event-calendar-day]]:w-full " \
                 "[&_[data-slot=event-calendar-day]]:rounded-md " \
                 "[&_[data-slot=event-calendar-day]]:border " \
                 "[&_[data-slot=event-calendar-ruler-pad]]:w-0"

        style do
          base { "#{Hours::Component::BASE} #{TOKENS}" }
        end

        attr_reader :showing

        # @param showing [Symbol] `:both`, `:axis` or `:agenda`
        def initialize(showing: :both, **attributes)
          @showing = SHOWING.include?(showing&.to_sym) ? showing.to_sym : :both
          super(**attributes)
        end

        def view = :daily

        # No date column, and not drawn rather than hidden. The title already
        # says which day this is, and in a month the column exists because
        # forty-two rows have to say which is which.
        #
        # Hiding it was the first attempt and lost: `ROWS_TOKENS` sets that slot
        # to `flex`, this would have set it to `none`, and at equal specificity
        # the winner is whichever Tailwind emitted last. The rule a reading has
        # to undo is the one that should not have been rendered — which is the
        # third time this file has learned it.
        def cell_body(day, on_day:, assignees:, hidden:) = [ day_axis(day) ]

        private

        def axis? = showing != :agenda

        def agenda? = showing != :axis

        def reading_label = shadcn_t("event_calendar.daily.#{showing}")

        def reading_options = [ showing_items ]

        def showing_items
          safe_join([
            render(DropdownMenu::Label::Component.new) { shadcn_t("event_calendar.daily.label") },
            render(DropdownMenu::Separator::Component.new),
            render(DropdownMenu::RadioGroup::Component.new) do
              safe_join(SHOWING.map { |name| showing_item(name) })
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

        # The title is a date rather than a month, because that is what changed.
        def title
          tag.div(I18n.l(selected, format: agenda_format),
                  "data-slot": "event-calendar-title", class: TITLE_CLASS,
                  role: "status", "aria-live": "polite")
        end

        # `‹` and `›` step a day here, not a month.
        def step_button(direction)
          target = selected + (direction == :previous ? -1 : 1)

          nav_button(target, size: :"icon-sm", action: STEP_ACTIONS.fetch(direction),
                     label: shadcn_t("event_calendar.#{direction}_day")) do
            render(Icon::Component.new(direction == :previous ? "chevron-left" : "chevron-right",
                                       class: CHEVRON_CLASS))
          end
        end

        # One day's row, with the scale above it — no weekday strip, no weeks,
        # and no `role="grid"`, because there is no grid to describe.
        def grid
          return unless axis?

          tag.div(safe_join([ scale, day_row ].compact),
                  "data-slot": "event-calendar-grid", class: FRAME_CLASS)
        end

        def day_row
          tag.div(day_cell(selected, on_day: schedule.on(selected),
                                     assignees: schedule.assignees_on(selected), hidden: 0),
                  "data-slot": "event-calendar-weeks", class: WEEKS_CLASS,
                  role: "list", "aria-label": I18n.l(selected, format: agenda_format))
        end
      end
    end
  end
end
