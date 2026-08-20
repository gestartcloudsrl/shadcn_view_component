# frozen_string_literal: true

module Shadcn
  module EventCalendar
    # A month of events — FullCalendar's `dayGridMonth`, in one component.
    #
    # There is no upstream to be 1:1 with: `vendor/shadcn/ui` has `calendar.tsx`,
    # which is the day *picker*, and nothing that shows what is happening on a
    # day. So every class this renders is this port's, listed one by one in
    # `spec/reverse_parity_spec.rb` for the same reason the toaster's are.
    # See [features/event-calendar.md](../../../../.claude/docs/features/event-calendar.md).
    #
    # What it borrows instead of reinventing:
    #
    # * the grid, from `Calendar::Month` — which already reads
    #   `Date.beginning_of_week` from the host and already knows which days fall
    #   outside the month;
    # * the nav buttons, from `Button::Component`, so the toolbar is upstream's
    #   markup rather than a lookalike;
    # * the two rules the calendar's controller is written to — no text of its
    #   own and no class of its own — which is what keeps the JavaScript from
    #   becoming a second, differently-spelled copy of this file.
    #
    # **Mobile and desktop are two readings, not one scaled down.** Below `sm`
    # a cell is a number and up to `max_events` dots, and the events are read in
    # the agenda underneath — the phone pattern, because a 48px-wide cell can
    # hold a title or be legible and not both. From `sm` up the cell grows and
    # the events land in it as bars, laid out by `Schedule` so that a three-day
    # event is one bar across three columns.
    class Component < ApplicationViewComponent
      # Each colour is two custom properties, declared once on the root as
      # descendant rules rather than as utilities on every chip and every dot.
      # Two things follow, and both are the reason for the shape: an element is
      # recoloured by setting one `data-color`, so the controller carries no
      # colour table into JavaScript — and a month of thirty dots does not
      # repeat seventeen tokens thirty times in the HTML.
      #
      # The inks are the 800/300 pair rather than the 500 the dot uses, and both
      # halves of that were measured rather than chosen: 500 on a 12%-tinted
      # background is around 3:1, and 700 is 4.41 — under AA by six hundredths,
      # which is exactly the kind of miss `accessibility_spec` exists to catch
      # and an eye does not.
      COLOR_TOKENS =
        "[&_[data-color=default]]:[--event-color:var(--primary)] " \
        "[&_[data-color=default]]:[--event-ink:var(--foreground)] " \
        "[&_[data-color=blue]]:[--event-color:var(--color-blue-500)] " \
        "[&_[data-color=blue]]:[--event-ink:var(--color-blue-800)] " \
        "dark:[&_[data-color=blue]]:[--event-ink:var(--color-blue-300)] " \
        "[&_[data-color=green]]:[--event-color:var(--color-emerald-500)] " \
        "[&_[data-color=green]]:[--event-ink:var(--color-emerald-800)] " \
        "dark:[&_[data-color=green]]:[--event-ink:var(--color-emerald-300)] " \
        "[&_[data-color=amber]]:[--event-color:var(--color-amber-500)] " \
        "[&_[data-color=amber]]:[--event-ink:var(--color-amber-800)] " \
        "dark:[&_[data-color=amber]]:[--event-ink:var(--color-amber-300)] " \
        "[&_[data-color=rose]]:[--event-color:var(--color-rose-500)] " \
        "[&_[data-color=rose]]:[--event-ink:var(--color-rose-800)] " \
        "dark:[&_[data-color=rose]]:[--event-ink:var(--color-rose-300)] " \
        "[&_[data-color=violet]]:[--event-color:var(--color-violet-500)] " \
        "[&_[data-color=violet]]:[--event-ink:var(--color-violet-800)] " \
        "dark:[&_[data-color=violet]]:[--event-ink:var(--color-violet-300)]"

      # Past six a cell has stopped being a day on a calendar and become a list
      # that happens to be square, so this is where `max_events` clamps.
      MAX_EVENTS = (1..6).freeze

      # One lane, and the gap under it. The cell's height is derived from these
      # two in `#cell_height`, so changing a bar's height does not leave the
      # cells the wrong size.
      LANE_HEIGHT = 1.375
      LANE_GAP = 0.25
      # The strip at the top of a cell that the day number occupies, which the
      # bars start below.
      NUMBER_HEIGHT = 2.0

      HEADER_CLASS = "flex flex-wrap items-center justify-between gap-2 pb-3"
      TITLE_CLASS = "text-base leading-none font-semibold sm:text-lg"
      NAV_CLASS = "flex items-center gap-1"
      CHEVRON_CLASS = "size-4"
      FRAME_CLASS = "overflow-hidden rounded-md border"
      WEEKDAYS_CLASS = "grid grid-cols-7 border-b bg-muted/50"
      WEEKDAY_CLASS = "py-2 text-center text-[0.7rem] font-medium text-muted-foreground select-none sm:text-xs"
      # `gap-px` over a `bg-border` parent, rather than a border on each cell:
      # borders double up where two cells meet and the grid ends up with lines
      # of two widths, which is the thing a month grid cannot have.
      WEEKS_CLASS = "flex flex-col gap-px bg-border"
      WEEK_CLASS = "relative"
      DAYS_CLASS = "grid grid-cols-7 gap-px"
      DAY_CLASS = "group/day relative flex min-h-14 w-full flex-col items-center gap-1 bg-background px-1 " \
                  "pt-1.5 pb-1 text-left outline-none transition-colors hover:bg-accent/50 " \
                  "focus-visible:z-10 focus-visible:ring-[3px] focus-visible:ring-ring/50 " \
                  "focus-visible:ring-inset data-[selected]:bg-accent " \
                  "sm:min-h-(--event-calendar-cell) sm:items-start sm:px-1.5 " \
                  "sm:group-data-[overflow]/event-calendar:min-h-(--event-calendar-cell-more)"
      DAY_NUMBER_CLASS = "flex size-6 shrink-0 items-center justify-center rounded-full text-xs " \
                         "font-medium tabular-nums select-none " \
                         "group-data-[outside]/day:text-muted-foreground " \
                         "group-data-[today]/day:bg-primary group-data-[today]/day:font-semibold " \
                         "group-data-[today]/day:text-primary-foreground sm:text-[0.8rem]"
      DOTS_CLASS = "flex max-w-full flex-wrap items-center justify-center gap-0.5 sm:hidden"
      DOT_CLASS = "size-1.5 shrink-0 rounded-full bg-(--event-color)"
      # `text-foreground` rather than the muted grey it looks like it wants:
      # muted on a *selected* cell's `bg-accent` measures 4.34, and this line
      # carries information — how many events the cell did not have room for.
      MORE_CLASS = "mt-auto hidden w-full truncate text-left text-[0.7rem] font-medium " \
                   "select-none sm:block"
      # `aria-hidden`, and deliberately: the bars repeat what the day button
      # already carries in its name and what the agenda reads out in full, and a
      # screen reader hearing every event twice is worse than not seeing the
      # decoration. They are also `pointer-events-none` — one tap target per
      # day is the whole mobile-first bargain, and it holds on desktop too.
      SEGMENTS_CLASS = "pointer-events-none absolute inset-x-0 top-8 hidden auto-rows-[1.625rem] " \
                       "grid-cols-7 gap-x-px px-px sm:grid"
      EVENT_CLASS = "mx-px flex h-5.5 min-w-0 items-center gap-1 self-start rounded-sm " \
                    "bg-[var(--event-color)]/12 px-1.5 text-[0.7rem] leading-none font-medium " \
                    "text-(--event-ink) data-[continues-before]:rounded-l-none " \
                    "data-[continues-after]:rounded-r-none"
      EVENT_DOT_CLASS = "size-1.5 shrink-0 rounded-full bg-(--event-color)"
      # No `opacity-70` on the time, however much it wants one: dimming the ink
      # this chip already tinted its background for takes it under AA.
      EVENT_TIME_CLASS = "shrink-0 tabular-nums"
      EVENT_TITLE_CLASS = "truncate"
      AGENDA_CLASS = "mt-3"
      AGENDA_TITLE_CLASS = "px-2 pb-1.5 text-sm font-medium"
      AGENDA_LIST_CLASS = "flex flex-col"
      AGENDA_ITEM_CLASS = "flex items-start gap-2.5 rounded-md px-2 py-2 text-sm"
      AGENDA_LINK_CLASS = "transition-colors hover:bg-accent focus-visible:outline-none " \
                          "focus-visible:ring-[3px] focus-visible:ring-ring/50"
      AGENDA_MARK_CLASS = "mt-1.5 size-2 shrink-0 rounded-full bg-(--event-color)"
      AGENDA_BODY_CLASS = "flex min-w-0 flex-col gap-0.5"
      AGENDA_EVENT_TITLE_CLASS = "truncate font-medium"
      AGENDA_META_CLASS = "truncate text-xs text-muted-foreground"
      AGENDA_EMPTY_CLASS = "px-2 py-8 text-center text-sm text-muted-foreground"

      MONTH_FORMAT = "%B %Y"

      default_tag :div
      slot_name :"event-calendar"

      style do
        base { "group/event-calendar w-full text-foreground #{COLOR_TOKENS}" }
      end

      attr_reader :month, :selected, :max_events, :schedule

      # @param month [Date, nil] which month is shown; defaults to today's
      # @param selected [Date, nil] the day the agenda reads out; defaults to
      #   today when today is in view, and to the first of the month otherwise
      # @param events [Array<Hash, Event>] `{ title:, starts_at:, ends_at:,
      #   color:, url:, all_day: }` — `ends_at` is *inclusive*
      # @param max_events [Integer] bars per cell before a cell says "+2"
      # @param week_starts_on [Integer, nil] `Date#wday`; the host's
      #   `Date.beginning_of_week` when not given
      def initialize(month: nil, selected: nil, events: nil, max_events: 3,
                     week_starts_on: nil, **attributes)
        @month = Calendar::Month.new(month || Date.current, week_starts_on:)
        @max_events = max_events.to_i.clamp(MAX_EVENTS.first, MAX_EVENTS.last)
        @selected = (selected || default_selection).to_date
        @schedule = Schedule.new(month: @month, events:, max_lanes: @max_events)
        super(**attributes)
      end

      def element_attributes(**defaults)
        super(**{
          "data-controller" => "shadcn--event-calendar",
          "style" => merged_style("--event-calendar-cell:#{cell_height}rem",
                                  "--event-calendar-cell-more:#{cell_height(more: true)}rem"),
          # Read by the `sm:group-data-[overflow]` rule on the cells, and reset
          # by the controller when it draws a month with a different answer.
          "data-overflow" => ("true" if schedule.overflow?),
          "data-shadcn--event-calendar-month-value" => month.first.iso8601,
          # The application's today, not the browser's — the same reason the
          # calendar crosses one: `Time.zone` and a laptop's clock disagree by a
          # day for a few hours out of every twenty-four.
          "data-shadcn--event-calendar-today-value" => Date.current.iso8601,
          "data-shadcn--event-calendar-selected-value" => selected.iso8601,
          "data-shadcn--event-calendar-week-starts-on-value" => month.week_starts_on,
          "data-shadcn--event-calendar-max-events-value" => max_events,
          "data-shadcn--event-calendar-events-value" => portable_events.to_json,
          # Everything below is text, and all of it comes from `I18n` for the
          # reason the calendar's does: a `toLocaleDateString` in the controller
          # answers to the *browser's* locale, and the month you navigate to
          # would be spelled differently from the one you started on.
          "data-shadcn--event-calendar-locale-value" => I18n.locale.to_s,
          "data-shadcn--event-calendar-day-names-value" => I18n.t("date.day_names").to_json,
          "data-shadcn--event-calendar-short-day-names-value" => I18n.t("date.abbr_day_names").to_json,
          "data-shadcn--event-calendar-month-names-value" => I18n.t("date.month_names").drop(1).to_json,
          "data-shadcn--event-calendar-short-month-names-value" =>
            I18n.t("date.abbr_month_names").drop(1).to_json,
          "data-shadcn--event-calendar-month-format-value" => MONTH_FORMAT,
          "data-shadcn--event-calendar-day-format-value" => day_format,
          "data-shadcn--event-calendar-agenda-format-value" => agenda_format,
          # Fetched with the placeholders as their own arguments, so what
          # crosses is the template rather than a rendered sentence.
          "data-shadcn--event-calendar-day-label-value" =>
            shadcn_t("event_calendar.day_label", date: "%{date}", events: "%{events}"),
          "data-shadcn--event-calendar-more-label-value" =>
            shadcn_t("event_calendar.more", count: "%{count}"),
          # The plural *forms*, not a rendered one — the controller has to
          # pluralise a count the server never saw. It does it with
          # `Intl.PluralRules` over the locale above, which is the only way to
          # be right in a language with more than two forms.
          "data-shadcn--event-calendar-event-count-value" => event_count_forms.to_json
        }.compact.merge(defaults))
      end

      def call
        render_element(body: safe_join([ header, grid, agenda, prototypes ]))
      end

      private

      def default_selection
        Date.current.between?(month.first, month.last) ? Date.current : month.first
      end

      # Two rows of lanes need less room than four, and a month with a "+2" in
      # it needs one row more than its lanes — otherwise that line lands under
      # the last bar, which is where it was until somebody looked at the page.
      # Derived rather than written as a class, because `max_events` is an
      # argument and Tailwind never sees a class built at runtime.
      def cell_height(more: false)
        lanes = max_events + (more ? 1 : 0)

        (NUMBER_HEIGHT + (lanes * (LANE_HEIGHT + LANE_GAP)) + LANE_GAP).round(3)
      end

      # --- the toolbar ----------------------------------------------------------

      def header
        tag.div(safe_join([ title, nav ]), "data-slot": "event-calendar-header", class: HEADER_CLASS)
      end

      # `role="status"`, as the calendar's caption carries: the month is the one
      # thing on the page that changes when the nav is pressed, and a screen
      # reader has to hear it without being moved.
      def title
        tag.div(I18n.l(month.date, format: MONTH_FORMAT),
                "data-slot": "event-calendar-title", class: TITLE_CLASS,
                role: "status", "aria-live": "polite",
                "data-shadcn--event-calendar-target": "title")
      end

      def nav
        tag.div(
          safe_join([
            render(Button::Component.new(
              variant: :outline, size: :sm,
              "data-action": "click->shadcn--event-calendar#today"
            ).with_content(shadcn_t("event_calendar.today"))),
            step_button(:previous),
            step_button(:next)
          ]),
          "data-slot": "event-calendar-nav", class: NAV_CLASS
        )
      end

      def step_button(direction)
        render(Button::Component.new(
          variant: :outline, size: :"icon-sm",
          "data-action": "click->shadcn--event-calendar##{direction}",
          "aria-label": shadcn_t("event_calendar.#{direction}")
        ).with_content(
          render(Icon::Component.new(direction == :previous ? "chevron-left" : "chevron-right",
                                     class: CHEVRON_CLASS))
        ))
      end

      # --- the month ------------------------------------------------------------

      def grid
        tag.div(safe_join([ weekdays, weeks ]),
                "data-slot": "event-calendar-grid", class: FRAME_CLASS)
      end

      # `aria-hidden`: each day button already carries its whole date, so the
      # column headings are decoration by the time anything reads them.
      def weekdays
        names = I18n.t("date.abbr_day_names")

        tag.div(
          safe_join(month.weekday_numbers.map do |number|
            tag.div(names[number], "data-slot": "event-calendar-weekday", class: WEEKDAY_CLASS)
          end),
          "data-slot": "event-calendar-weekdays", class: WEEKDAYS_CLASS, "aria-hidden": "true"
        )
      end

      def weeks
        tag.div(safe_join(schedule.weeks.map { |week| week_row(week) }),
                "data-slot": "event-calendar-weeks", class: WEEKS_CLASS,
                "data-shadcn--event-calendar-target": "weeks")
      end

      # `blank:` is what the `<template>` at the bottom renders through: the
      # same method, with the events left out, so the shape the controller
      # clones cannot drift from the shape the server paints.
      def week_row(week, blank: false)
        cells = week.days.map do |day|
          day_cell(day,
                   on_day: blank ? [] : schedule.on(day),
                   hidden: blank ? 0 : week.hidden_on(day))
        end

        tag.div(
          safe_join([
            tag.div(safe_join(cells), "data-slot": "event-calendar-days", class: DAYS_CLASS),
            segments(week)
          ]),
          "data-slot": "event-calendar-week", class: WEEK_CLASS
        )
      end

      def day_cell(day, on_day:, hidden:)
        tag.button(
          safe_join([ day_number(day), dots(on_day), more(hidden) ].compact),
          type: "button",
          "data-slot": "event-calendar-day",
          class: DAY_CLASS,
          "data-day": day.iso8601,
          "data-today": ("true" if day == Date.current),
          "data-selected": ("true" if day == selected),
          "data-outside": ("true" if month.outside?(day)),
          "aria-current": ("date" if day == Date.current),
          "aria-pressed": (day == selected).to_s,
          "aria-label": day_label(day, on_day.size),
          "data-action": "click->shadcn--event-calendar#select"
        )
      end

      def day_number(day)
        tag.span(day.day, "data-slot": "event-calendar-day-number", class: DAY_NUMBER_CLASS)
      end

      # The phone's whole vocabulary for "something happens here". Capped at
      # `max_events` for the same reason the bars are: past four, dots stop
      # counting and start being texture.
      def dots(on_day)
        return if on_day.empty?

        tag.span(
          safe_join(on_day.first(max_events).map do |event|
            tag.span("", "data-slot": "event-calendar-day-dot", class: DOT_CLASS,
                     "data-color": event.color)
          end),
          "data-slot": "event-calendar-day-dots", class: DOTS_CLASS
        )
      end

      def more(count)
        return if count.zero?

        tag.span(shadcn_t("event_calendar.more", count:),
                 "data-slot": "event-calendar-day-more", class: MORE_CLASS)
      end

      def segments(week)
        tag.div(
          safe_join(week.visible.map { |segment| event_bar(segment) }),
          "data-slot": "event-calendar-segments", class: SEGMENTS_CLASS, "aria-hidden": "true"
        )
      end

      def event_bar(segment)
        event = segment.event

        tag.div(
          safe_join([
            (tag.span("", "data-slot": "event-calendar-event-dot", class: EVENT_DOT_CLASS) unless event.all_day?),
            (tag.span(chip_time(event), "data-slot": "event-calendar-event-time",
                      class: EVENT_TIME_CLASS) if chip_time(event)),
            tag.span(event.title, "data-slot": "event-calendar-event-title", class: EVENT_TITLE_CLASS)
          ].compact),
          "data-slot": "event-calendar-event",
          class: EVENT_CLASS,
          # The one place this component positions with a style rather than a
          # class, and the reason is the controller: `col-start-#{n}` cannot be
          # built at runtime on either side — Tailwind never sees it here, and
          # a controller that carried the seven spellings would own classes,
          # which is the thing its second rule forbids. Grid line numbers are
          # what those classes compile to anyway, so both sides write the same
          # two declarations and cannot drift.
          style: "grid-column:#{segment.column} / span #{segment.span};grid-row:#{segment.lane}",
          "data-color": event.color,
          "data-continues-before": ("true" if segment.continues_before?),
          "data-continues-after": ("true" if segment.continues_after?),
          title: event.title
        )
      end

      # --- the agenda -----------------------------------------------------------

      # The mobile reading surface, and the desktop detail panel — one mechanism
      # rather than two, which is what lets the grid have a single tap target
      # per day at every width.
      def agenda
        on_day = schedule.on(selected)

        tag.div(
          safe_join([
            tag.div(I18n.l(selected, format: agenda_format),
                    "data-slot": "event-calendar-agenda-title", class: AGENDA_TITLE_CLASS,
                    "data-shadcn--event-calendar-target": "agendaTitle"),
            tag.ul(safe_join(on_day.map { |event| agenda_item(event) }),
                   "data-slot": "event-calendar-agenda-list", class: AGENDA_LIST_CLASS,
                   "data-shadcn--event-calendar-target": "agendaList"),
            tag.p(shadcn_t("event_calendar.empty"),
                  "data-slot": "event-calendar-agenda-empty", class: AGENDA_EMPTY_CLASS,
                  hidden: on_day.any?,
                  "data-shadcn--event-calendar-target": "agendaEmpty")
          ]),
          "data-slot": "event-calendar-agenda", class: AGENDA_CLASS,
          role: "region", "aria-live": "polite",
          "aria-label": shadcn_t("event_calendar.agenda_label")
        )
      end

      def agenda_item(event)
        tag.li(agenda_row(event), "data-slot": "event-calendar-agenda-item", "data-color": event.color)
      end

      def agenda_row(event)
        body = safe_join([
          tag.span("", "data-slot": "event-calendar-agenda-mark", class: AGENDA_MARK_CLASS),
          tag.span(
            safe_join([
              tag.span(event.title, "data-slot": "event-calendar-agenda-event-title",
                       class: AGENDA_EVENT_TITLE_CLASS),
              tag.span(agenda_meta(event), "data-slot": "event-calendar-agenda-meta",
                       class: AGENDA_META_CLASS)
            ]),
            "data-slot": "event-calendar-agenda-body", class: AGENDA_BODY_CLASS
          )
        ])

        # The `<li>` carries the colour and this carries the classes, because
        # only one of the two can be an `<a>` and a clone cannot change its own
        # tag name — which is why the `<template>` at the bottom holds both.
        return tag.div(body, "data-slot": "event-calendar-agenda-row", class: AGENDA_ITEM_CLASS) if event.url.blank?

        tag.a(body, href: event.url, "data-slot": "event-calendar-agenda-row",
              class: "#{AGENDA_ITEM_CLASS} #{AGENDA_LINK_CLASS}")
      end

      # --- what the controller clones -------------------------------------------

      # A month with no events has no bar to clone, and a controller that writes
      # one out in a template literal is a controller with classes of its own —
      # which is the thing the calendar's two rules exist to prevent. So the
      # shapes are rendered here, once, into a `<template>` the browser does not
      # paint and Tailwind does scan.
      def prototypes
        tag.template(
          safe_join([
            week_row(Schedule::Week.new(days: month.weeks.first, segments: [], max_lanes: max_events),
                     blank: true),
            event_bar(Schedule::Segment.new(event: prototype_event, column: 1, span: 1, lane: 1)),
            dots([ prototype_event ]),
            more(1),
            agenda_item(prototype_event),
            agenda_item(prototype_link_event)
          ]),
          "data-shadcn--event-calendar-target": "prototypes"
        )
      end

      # Timed rather than all-day, and that is the whole point of it: an
      # all-day chip renders neither a dot nor a time, and the controller
      # cannot clone a child that was never there. It removes the two it does
      # not need instead, which is the direction that works.
      def prototype_event = Event.new(title: "", starts_at: month.first.in_time_zone)

      def prototype_link_event = Event.new(title: "", starts_at: month.first.in_time_zone, url: "#")

      # --- text -----------------------------------------------------------------

      # Everything a person reads on an event is formatted here and travels to
      # the controller already written, so that the JavaScript never formats a
      # time. Its `strftime` shim reads the date patterns Rails' own locales are
      # written in; times have `%p`, `%l` and `%M`, which it does not, and
      # teaching it those would be a second locale implementation.
      def portable_events
        # Two orderings cross, because the controller needs both and can derive
        # neither: the array's own order is the one `Schedule#pack` packs in,
        # and `dayOrder` is the one a person reads a single day in. Sorting
        # again in JavaScript would be a second `sort_key`, spelled differently.
        by_day = schedule.events.sort_by(&:day_sort_key).each_with_index.to_h

        schedule.events.map do |event|
          {
            id: event.id,
            dayOrder: by_day[event],
            title: event.title,
            color: event.color,
            from: event.start_date.iso8601,
            to: event.end_date.iso8601,
            allDay: event.all_day?,
            time: chip_time(event),
            meta: agenda_meta(event),
            url: event.url.presence
          }
        end
      end

      def chip_time(event)
        return if event.all_day?

        I18n.l(event.starts_at, format: time_format)
      end

      # The agenda's second line: a clock for a timed event, the span for one
      # that crosses days, and the words for an all-day one.
      def agenda_meta(event)
        return date_span(event) if event.multi_day?
        return shadcn_t("event_calendar.all_day") if event.all_day?
        return chip_time(event) if event.ends_at.blank?

        "#{chip_time(event)} – #{I18n.l(event.ends_at, format: time_format)}"
      end

      def date_span(event)
        "#{I18n.l(event.start_date, format: :short)} – #{I18n.l(event.end_date, format: :short)}"
      end

      def day_label(day, count)
        date = I18n.l(day, format: day_format)
        return date if count.zero?

        shadcn_t("event_calendar.day_label", date:, events: shadcn_t("event_calendar.event_count", count:))
      end

      def event_count_forms
        key = "shadcn_view_component.event_calendar.event_count"

        I18n.t(key, default: ->(*) { I18n.t(key, locale: :en) })
      end

      def time_format = shadcn_t("event_calendar.time_format")

      def day_format = "%A, #{I18n.t('date.formats.long')}"

      def agenda_format = shadcn_t("event_calendar.agenda_format")
    end
  end
end
