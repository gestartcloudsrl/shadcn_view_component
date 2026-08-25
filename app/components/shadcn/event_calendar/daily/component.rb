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
        include Groupings

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

        # Its own slot, not the date column's. That column is `w-14` and centres
        # what it holds, which is right for "Tue 4" and wrong for "Katherine
        # Johnson" — it clipped her to "atherine Johnson" and dropped the count
        # to the foot of a stretched row. Borrowing the slot would have meant
        # undoing three of the frame's rules; a name of its own has none to undo.
        RESOURCE_CLASS = "flex w-32 shrink-0 items-center gap-1.5 self-stretch pt-1"
        RESOURCE_NAME_CLASS = "min-w-0 flex-1 truncate text-[0.7rem] font-medium"

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

        def reading_label
          safe_join([ shadcn_t("event_calendar.daily.#{showing}"), grouping_label ], " · ")
        end

        def reading_options = [ showing_items, grouping_items ]

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
          rows = by_assignee? ? assignee_rows : [ day_cell(selected, on_day: schedule.on(selected),
                                                           assignees: [], hidden: 0) ]

          tag.div(safe_join(rows),
                  "data-slot": "event-calendar-weeks", class: WEEKS_CLASS,
                  role: "list", "aria-label": I18n.l(selected, format: agenda_format))
        end

        # A row per operator, which is the question a day actually gets asked:
        # not "what is on" but "who is where, and who is free at two". Each row
        # packs its lanes among that person's own jobs, so two people working at
        # the same hour do not push each other down.
        def assignee_rows
          schedule.assignees_on(selected).map do |assignee, count|
            tag.div(
              safe_join([
                tag.span(safe_join([ tag.span(assignee.name, class: RESOURCE_NAME_CLASS),
                                     count_chip(count) ].compact),
                         "data-slot": "event-calendar-resource", class: RESOURCE_CLASS),
                assignee_axis(assignee)
              ]),
              "data-slot": "event-calendar-day", class: [ DAY_CLASS, CELL_CLASS ],
              "data-day": selected.iso8601, role: "listitem"
            )
          end
        end

        # The list, cut the same way the axis is — a section per operator, in
        # the same order, so a reader who found someone above can find them
        # again below. Cut by event it is the parent's list unchanged.
        def agenda
          return super unless by_assignee?

          tag.public_send(agenda_as,
            safe_join(schedule.assignees_on(selected).map { |assignee, count|
              assignee_section(assignee, count)
            }),
            **agenda_attributes, "data-slot": "event-calendar-agenda", class: AGENDA_CLASS)
        end

        def assignee_section(assignee, count)
          on_them = schedule.on(selected).select { |event| event.assignees.any? { |a| a.name == assignee.name } }

          safe_join([
            tag.div(safe_join([ tag.span(assignee.name),
                                tag.span(agenda_count(count), "data-slot": "event-calendar-agenda-count",
                                         class: AGENDA_COUNT_CLASS) ]),
                    "data-slot": "event-calendar-agenda-title", class: AGENDA_TITLE_CLASS),
            tag.ul(safe_join(on_them.map { |event| agenda_item(event) }),
                   "data-slot": "event-calendar-agenda-list", class: AGENDA_LIST_CLASS)
          ])
        end

        def assignee_axis(assignee)
          placed = schedule.track_on(selected, floor: floor_minutes, for_assignee: assignee.name)
          lanes = placed.map { |_, lane, _, _| lane }.max.to_i + 1

          tag.span(safe_join(placed.map { |slot| draw(selected, *slot) }),
                   "data-slot": "event-calendar-day-track",
                   class: [ AXIS_CLASS, GRIDLINES_CLASS, AXIS_HEIGHT_CLASS ],
                   style: "--lanes:#{lanes};--lane-h:#{LANE_HEIGHTS.fetch(shape)}rem")
        end
      end
    end
  end
end
