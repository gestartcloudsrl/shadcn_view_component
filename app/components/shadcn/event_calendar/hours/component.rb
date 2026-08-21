# frozen_string_literal: true

module Shadcn
  module EventCalendar
    module Hours
      # A month read as a **timeline**: every job placed at the hour it starts,
      # so the same x is the same hour on every row.
      #
      # The third of the three readings, and the reason there are three. A day
      # is a list of events in `EventCalendar::Component`, a quantity of work in
      # the workload reading, and here it is an axis — three different questions
      # with three different answers, which is why they stopped sharing a file.
      # What they still share is the domain: `Calendar::Month`, `Schedule` and
      # `Event` are the parent's and are not duplicated here.
      #
      # A host never names this class. `EventCalendar::Component.new(reading:
      # :hours)` hands over to it — see `Component::RENDERERS`.
      #
      # **The axis fits; it does not scroll per row.** Each row owns its own
      # overflow, so two rows scrolled to different offsets would put the same
      # hour at two different x — exactly the alignment the reading exists for.
      # Fitting costs the labels: sixteen hours across ~1200px is 75px an hour,
      # so an hour-long job is a 75px bar and its text lives in `title=`. On a
      # phone that trade stops working, and there the hour takes a fixed width
      # and the *month* scrolls as one, with the date column frozen.
      class Component < EventCalendar::Component
        include Chips

        # No `data-[track]:` prefix on any of these, and that absence is the
        # split doing its job: these rules only ever land on this class's root,
        # so scoping them to an attribute would be guarding against a calendar
        # that cannot reach them. They were prefixed while every reading shared
        # one root and one class string.
        TOKENS =
          "[--event-calendar-hour:0px] " \
          "max-lg:[--event-calendar-hour:22vw] " \
          "[&_[data-slot=event-calendar-grid]]:overflow-x-auto " \
          "[&_[data-slot=event-calendar-weeks]]:min-w-(--event-calendar-track) " \
          "[&_[data-slot=event-calendar-ruler]]:min-w-(--event-calendar-track) " \
          "[&_[data-slot=event-calendar-day]]:min-h-14 " \
          "[&_[data-slot=event-calendar-day]]:items-start " \
          "[&_[data-slot=event-calendar-day-head]]:sticky " \
          "[&_[data-slot=event-calendar-day-head]]:left-0 " \
          "[&_[data-slot=event-calendar-day-head]]:z-10 " \
          "[&_[data-slot=event-calendar-day-head]]:self-stretch " \
          "[&_[data-slot=event-calendar-day-head]]:justify-start " \
          "[&_[data-slot=event-calendar-day-head]]:pt-1.5 " \
          "[&_[data-slot=event-calendar-day-head]]:bg-background " \
          "[&_[data-slot=event-calendar-ruler-pad]]:sticky " \
          "[&_[data-slot=event-calendar-ruler-pad]]:left-0 " \
          "[&_[data-slot=event-calendar-ruler-pad]]:z-10 " \
          "[&_[data-slot=event-calendar-ruler-pad]]:self-stretch " \
          "[&_[data-slot=event-calendar-ruler-pad]]:bg-background"

        style do
          base { "#{EventCalendar::Component::BASE_TOKENS} #{EventCalendar::Component::ROWS_TOKENS} " \
                 "#{TOKENS}" }
        end

        AXIS_CLASS = "relative min-w-0 grow self-stretch"
        # Eight gridlines, matching the eight marks `#hour_marks` draws, whatever
        # window the axis is showing. A gradient rather than twenty-four
        # elements: they are decoration, and a node each would be a thousand of
        # them in a month.
        GRIDLINES_CLASS = "bg-[repeating-linear-gradient(to_right,var(--border)_0_1px,transparent_1px_12.5%)]"
        AXIS_HEIGHT_CLASS = "h-[calc((var(--lanes)*var(--lane-h))+0.35rem)]"
        BAR_CLASS = "absolute top-(--lane) left-(--at) h-2 w-(--for) min-w-[3px] rounded-full"
        BAR_PAINT_CLASS = "bg-[var(--event-color)]/70 ring-1 ring-background"
        # A chip is placed by its start and sized by its content, so `--for` is
        # not used here at all: the duration stops being a length and goes back
        # to being the text in the clock. `max-w` is what stops a late-evening
        # chip running off the end of the axis.
        # No width in here, and that is the point. A chip carries exactly one of
        # the two below, because both are `width` and this string does not go
        # through `tailwind_merge` — put them together and the winner is
        # whichever Tailwind emitted last, which was `w-auto`: an all-day chip
        # said `--for:100%`, wore `w-(--for)`, and rendered 124px wide inside a
        # 1270px axis.
        CHIP_CLASS = "absolute top-(--lane) left-(--at) flex flex-col gap-1 " \
                     "overflow-hidden rounded-md border border-border/40 " \
                     "bg-[var(--event-color)]/12 px-1.5 py-1 text-(--event-ink)"
        # As wide as its own text, capped so a late-evening chip does not run
        # off the end of the axis.
        CHIP_TIMED_CLASS = "w-auto max-w-[13rem]"
        # The one chip whose width means something: an all-day job has no hour
        # to be placed at, so it is the whole axis — and running to the end is
        # exactly what it is for, so there is no cap.
        CHIP_ALL_DAY_CLASS = "w-(--for)"
        # A share of the window, not a number of minutes — which is the bug the
        # first version had. The packer speaks minutes, but what decides whether
        # two chips collide is *pixels*, and how many pixels a minute is worth
        # depends on how many hours are showing. 120 minutes was a tenth of a
        # 07–23 window and a twelfth of a 00–24 one, so the same floor that kept
        # them apart on the short window let them pile up on the long one.
        #
        # Measured: a chip runs 93–160px on a ~1370px axis, so the widest is
        # under 12% of it.
        CHIP_SHARE = 0.12
        # Measured too: a chip renders 51px — a clock line, a gap and a title —
        # so a 2.9rem lane overlapped the next by five pixels and clipped the
        # bottom row of every busy day.
        LANE_HEIGHTS = { chips: 3.4, bars: 0.9 }.freeze

        # The scale, drawn once above the month rather than once per row: it is
        # the same hours on every row, and forty-two copies would be forty-two
        # chances to disagree. The pad is the width of the date column, so mark
        # zero starts where the axes do.
        # The same box as a row, and it has to be measured against one rather
        # than eyeballed: the pad matches the date column, but a day cell also
        # carries `px-2` and `gap-2`, so without them the scale started 16px to
        # the left of the axis and ran 24px wider — every hour label pointing
        # somewhere the gridlines were not.
        RULER_CLASS = "flex items-end gap-2 px-2 pb-1 text-[0.6rem] text-muted-foreground"
        RULER_PAD_CLASS = "w-14 shrink-0"
        RULER_BODY_CLASS = "relative h-4 grow"
        HOUR_CLASS = "absolute bottom-0 left-(--at) border-l border-border/60 pl-0.5"

        attr_reader :window, :shape, :shape_url

        # @param window [Range] the hours the axis shows. A calendar of field
        #   work spent thirty per cent of its width on midnight-to-seven —
        #   measured, not guessed: the bars ran 29.2% to 95.6% and nothing was
        #   ever drawn in the first third.
        # @param shape [Symbol] `:bars` — as wide as the job lasts, and nothing
        #   else said — or `:chips`, which say who and for whom and are as wide
        #   as that takes. On 447 events the month is 3437px of bars or 11114px
        #   of chips, so this is a density decision more than a taste one.
        # Not `as:`: that name is already the gem's, for the tag an element
        # renders as, and taking it here made every bar ask `LANE_HEIGHTS` for
        # a key of `nil`.
        # @param shape_url [#call, nil] given the wanted shape, the URL of that
        #   state. Present, the menu is links; absent, it dispatches. A shape is
        #   different markup, not a class toggle — drawing both and hiding one
        #   is the trade this reading spent a whole round removing.
        def initialize(window: (0..24), shape: :chips, shape_url: nil, **attributes)
          @window = window
          @shape_url = shape_url
          @shape = LANE_HEIGHTS.key?(shape&.to_sym) ? shape.to_sym : :chips
          super(**attributes)
        end

        def chips? = shape == :chips

        private

        # `3.5rem` is the date column's own `w-14`, which does not scroll.
        def reading_style
          [ "--event-calendar-track:calc(3.5rem + (#{window.last - window.first} * " \
            "var(--event-calendar-hour)))" ]
        end

        def scale
          tag.div(
            safe_join([
              tag.span("", "data-slot": "event-calendar-ruler-pad", class: RULER_PAD_CLASS),
              tag.span(safe_join(hour_marks.map { |hour| hour_mark(hour) }), class: RULER_BODY_CLASS)
            ]),
            "data-slot": "event-calendar-ruler", class: RULER_CLASS, "aria-hidden": "true"
          )
        end

        def cell_body(day, on_day:, assignees:, hidden:)
          [
            tag.span(safe_join([ day_marker(day), count_chip(on_day.size) ].compact),
                     "data-slot": "event-calendar-day-head", class: HEAD_CLASS),
            day_axis(day)
          ].compact
        end

        def client_drawn? = false

        def cell_class = CELL_CLASS

        def reading_attributes = { "data-rows" => "true", "data-arrangement" => :rows }

        # The one choice this reading has, in the slot the `Rows` toggle would
        # have had — which in an hours month could change nothing, because an
        # hours month *is* rows. A menu rather than a two-state toggle for the
        # same reason the grouping is one: a third shape is the obvious next
        # question, and a toggle would have to become this anyway.
        def view = :hours

        def reading_controls = [ view_panel ]

        def reading_label = shadcn_t("event_calendar.hours.#{shape}")

        def reading_options = [ shape_items ]

        def shape_items
          safe_join([
            render(DropdownMenu::Label::Component.new) { shadcn_t("event_calendar.hours.label") },
            render(DropdownMenu::Separator::Component.new),
            render(DropdownMenu::RadioGroup::Component.new) do
              safe_join(LANE_HEIGHTS.keys.map { |name| shape_item(name) })
            end
          ])
        end

        def shape_item(name)
          href = shape_url&.call(name)

          render(DropdownMenu::RadioItem::Component.new(
            value: name, checked: name == shape,
            **(href ? { as: :a, href: } : { "data-action": "click->shadcn--event-calendar#reshape" })
          )) { shadcn_t("event_calendar.hours.#{name}") }
        end

        # Position is a percentage of the window rather than a pixel, so the
        # marks stay aligned at every width without anything measuring anything.
        def day_axis(day)
          placed = schedule.track_on(day, floor: floor_minutes)
          lanes = placed.map { |_, lane, _, _| lane }.max.to_i + 1

          tag.span(safe_join(placed.map { |slot| draw(*slot) }),
                   "data-slot": "event-calendar-day-track",
                   class: [ AXIS_CLASS, GRIDLINES_CLASS, AXIS_HEIGHT_CLASS ],
                   style: "--lanes:#{lanes};--lane-h:#{LANE_HEIGHTS.fetch(shape)}rem")
        end

        # Clipped to the window before anything is drawn from it.
        #
        # `Schedule#track_on` answers in minutes of the *day*, because it has no
        # idea what the axis is showing — so on a 07–19 axis an all-day job came
        # back as 0..1440 and was drawn at −58% and two hundred per cent wide.
        # Any job outside the window did the same; the all-day case is only the
        # one that always is.
        def draw(event, lane, from, to)
          low, high = window.first * 60, window.last * 60
          slot = [ event, lane, from.clamp(low, high), to.clamp(low, high) ]

          chips? ? chip(*slot) : bar(*slot)
        end

        def bar(event, lane, from, to)
          tag.span(
            "", "data-slot": "event-calendar-day-bar",
            class: [ BAR_CLASS, BAR_PAINT_CLASS ],
            "data-color": event.color,
            style: "--at:#{at(from)};--for:#{span(to - from)};--lane:#{lane_offset(lane)}",
            title: [ chip_time(event), event.title ].compact.join(" — ")
          )
        end

        # The chip the workload reading already draws, placed by the clock — so
        # what the two readings differ in is the axis, not what an intervention
        # looks like.
        def chip(event, lane, from, to)
          tag.span(
            safe_join([ chip_head(event), chip_text(event) ]),
            "data-slot": "event-calendar-day-item",
            class: [ CHIP_CLASS, (event.all_day? ? CHIP_ALL_DAY_CLASS : CHIP_TIMED_CLASS) ],
            "data-color": event.color,
            style: [ "--at:#{at(from)}", ("--for:#{span(to - from)}" if event.all_day?),
                     "--lane:#{lane_offset(lane)}" ].compact.join(";"),
            title: [ chip_time(event), event.title ].compact.join(" — ")
          )
        end

        def floor_minutes
          return Schedule::TRACK_FLOOR unless chips?

          (window_minutes * CHIP_SHARE).round
        end

        def window_minutes = (window.last - window.first) * 60

        def lane_offset(lane) = "calc(#{lane} * var(--lane-h))"

        # Two of them, and the difference is the whole bug that made the first
        # windowed axis a field of three-pixel ticks: a *position* is measured
        # from the start of the window and a *length* is not, so subtracting the
        # window offset from a duration turned every hour-long job negative and
        # left `min-w` to draw it.
        def at(minutes) = span(minutes - (window.first * 60))

        def span(minutes) = "#{((minutes / (window_minutes * 1.0)) * 100).round(3)}%"

        def hour_marks
          step = ((window.last - window.first) / 8.0).ceil

          (window.first...window.last).step(step)
        end

        def hour_mark(hour)
          tag.span(format("%02d", hour), class: HOUR_CLASS, style: "--at:#{at(hour * 60)}")
        end
      end
    end
  end
end
