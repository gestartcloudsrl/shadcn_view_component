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
    # **A cell either names its events or shows their shape, never half of
    # each.** Named, it holds bars — laid out by `Schedule` so a three-day event
    # is one bar across three columns — and says "+2" when it runs out of lanes.
    # Showing the shape, it holds one mark per event, all of them, banded by
    # colour and sized against the busiest day in the month.
    #
    # Below `sm` it is always the marks: a 48px cell can hold a title or be
    # legible, not both. Above `sm` the busiest day decides, because past
    # `DENSE_ABOVE` a "+79" is not information — the bars above it are an
    # arbitrary sample and what the number counts is invisible until the day is
    # opened. See
    # [features/event-calendar.md](../../../../.claude/docs/features/event-calendar.md).
    #
    class Component < ApplicationViewComponent
      # Each colour is two custom properties, declared once on the root as
      # descendant rules rather than as utilities on every chip and every dot.
      # Two things follow, and both are the reason for the shape: an element is
      # recoloured by setting one `data-color`, so the controller carries no
      # colour table into JavaScript — and a month of thirty dots does not
      # repeat seventeen tokens thirty times in the HTML.
      #
      # `default` means *uncategorised*, so it is the quietest mark rather than
      # the loudest. It was `--primary` until a month of marks was looked at:
      # in the neutral palette that is near-black, which at four pixels carries
      # about twice the weight of the 500-level hues beside it and takes the
      # cell over. A mid grey is what "no category" should look like, and it
      # matches what the chip already did — its background was `primary/12`,
      # which is a light grey, so only the solid mark was ever loud.
      #
      # The inks are the 800/300 pair rather than the 500 the dot uses, and both
      # halves of that were measured rather than chosen: 500 on a 12%-tinted
      # background is around 3:1, and 700 is 4.41 — under AA by nine hundredths,
      # which is exactly the kind of miss `accessibility_spec` exists to catch
      # and an eye does not.
      COLOR_TOKENS =
        "[&_[data-color=default]]:[--event-color:var(--muted-foreground)] " \
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

      READINGS = %i[auto events workload hours daily].freeze

      # How the workload month is laid out. `:auto` is the breakpoint doing the
      # deciding — rows below `lg`, the seven-column grid above it — and
      # `:rows` is the toolbar overruling it. There is no `:grid`: forcing
      # seven columns onto a phone is the thing rows were built to avoid, so
      # the toggle only exists where it has something to change.
      ARRANGEMENTS = %i[auto rows].freeze

      # The three views the options panel offers, which is one list because a
      # person picking one is answering one question. Two of them are the
      # workload reading at two arrangements and the third is a different
      # reading entirely — a distinction that matters to this file and to
      # nobody using it, which is why `view_url:` is one callback and not two.
      VIEWS = %i[grid rows hours].freeze

      # The period the toolbar switches between, above the views. A month has
      # three ways of being read and a day has one; `PERIODS` is what the panel
      # asks first, and `VIEWS` is only the monthly follow-up.
      PERIODS = %i[monthly daily].freeze
      # Past the last hue, for a colour the palette does not know.
      COLORS_END = Event::COLORS.size
      # How a day *sits* in a row is each reading's own, and is deliberately not
      # here. Both of them said something about the cell's height, and with the
      # rules at equal specificity the winner was source order: the hours
      # reading's `h-auto` lost to this file's `h-20`, its axis grew to 150px
      # inside an 80px cell, and a busy day's lower lanes were drawn over the
      # next day's row. What had been holding that up was the `data-[track]:`
      # prefix — it was not only scoping the rules, it was winning them — and
      # taking it off is what let the fixed height through.
      #
      # A rule a reading has to undo does not belong to the frame.
      ROWS_TOKENS =
        "rows:[&_[data-slot=event-calendar-week]]:contents " \
        "rows:[&_[data-slot=event-calendar-days]]:contents " \
        "rows:[&_[data-slot=event-calendar-weekdays]]:hidden " \
        "rows:[&_[data-slot=event-calendar-day]]:flex-row " \
        "rows:[&_[data-slot=event-calendar-day]]:gap-2 " \
        "rows:[&_[data-slot=event-calendar-day]]:px-2 " \
        "rows:[&_[data-slot=event-calendar-day]]:py-2 " \
        "rows:[&_[data-slot=event-calendar-day][data-outside]]:hidden " \
        "rows:[&_[data-slot=event-calendar-day-head]]:flex " \
        "rows:[&_[data-slot=event-calendar-day-head]]:w-14 " \
        "rows:[&_[data-slot=event-calendar-day-head]]:shrink-0 " \
        "rows:[&_[data-slot=event-calendar-day-head]]:flex-col " \
        "rows:[&_[data-slot=event-calendar-day-head]]:items-center " \
        "rows:[&_[data-slot=event-calendar-day-head]]:justify-center " \
        "rows:[&_[data-slot=event-calendar-day-head]]:gap-1 " \
        "rows:[&_[data-slot=event-calendar-day-label]]:flex " \
        "rows:[&_[data-slot=event-calendar-day-label]]:w-full " \
        "rows:[&_[data-slot=event-calendar-day-label]]:flex-col " \
        "rows:[&_[data-slot=event-calendar-day-label]]:items-center " \
        "rows:[&_[data-slot=event-calendar-day-label]]:gap-0 " \
        "rows:[&_[data-slot=event-calendar-day-weekday]]:block " \
        "rows:[&_[data-slot=event-calendar-day-number]]:text-sm " \
        "rows:[&_[data-slot=event-calendar-segments]]:hidden " \
        "rows:[&_[data-slot=event-calendar-day-item]_[data-slot=avatar-group]]:flex"
      ROWS_LABEL_CLASS = "contents shrink-0 items-center gap-1"
      ROWS_WEEKDAY_CLASS = "hidden text-[0.7rem] font-normal text-muted-foreground tabular-nums"

      DENSE_ABOVE = 12

      # How big a mark is, against the busiest day in the month — `nil` is the
      # floor and matches anything. Crossed to the controller as a table rather
      # than as a resolved size, for the reason the plural forms are: it has to
      # choose again for a month the server never drew, and the numbers stay
      # here.
      #
      # Four pixels is the floor because it is what a hundred marks cost: at a
      # 5px pitch a ~48px cell fits nine to a row, eleven rows, and the busiest
      # day in the month still ends inside a phone screen.
      TICK_SIZES = [ [ 8, "0.4375rem" ], [ 24, "0.375rem" ], [ 60, "0.3125rem" ], [ nil, "0.25rem" ] ].freeze

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
      DAY_CLASS = "group/day relative flex min-h-14 w-full flex-col items-center gap-1 bg-background px-0.5 " \
                  "pt-1.5 pb-1 text-left outline-none transition-colors hover:bg-accent/50 " \
                  "focus-visible:z-10 focus-visible:ring-[3px] focus-visible:ring-ring/50 " \
                  "focus-visible:ring-inset data-[selected]:bg-accent " \
                  "sm:items-start sm:px-1.5 " \
                  "group-data-[labelled]/event-calendar:sm:min-h-(--event-calendar-cell) " \
                  "sm:group-data-[overflow]/event-calendar:min-h-(--event-calendar-cell-more)"
      DAY_NUMBER_CLASS = "flex size-6 shrink-0 items-center justify-center rounded-full text-xs " \
                         "font-medium tabular-nums select-none " \
                         "group-data-[outside]/day:text-muted-foreground " \
                         "group-data-[today]/day:bg-primary group-data-[today]/day:font-semibold " \
                         "group-data-[today]/day:text-primary-foreground sm:text-[0.8rem]"
      # The phone's whole vocabulary, and the answer to a day nobody can label:
      # one mark per event, every one of them drawn. `content-start` so a short
      # last row sits under the others rather than being stretched into them,
      # and `justify-center` because only that last row is ever short — a full
      # band fills the width either way, so centring costs nothing at eighty
      # events and is the difference between tidy and adrift at four.
      # Every mark's styling lives here, on the one element, rather than on each
      # of them. At this density that is not tidiness: a day of eighty bookings
      # is eighty elements, a month of them is two thousand, and the class
      # string below repeated two thousand times is half a megabyte of HTML for
      # a rule that never varies. What varies is `data-color` and the two run
      # attributes, so that is all a mark carries.
      TICKS_CLASS = "flex w-full flex-wrap content-start justify-center gap-px pt-0.5 " \
                    "group-data-[labelled]/event-calendar:sm:hidden " \
                    "[&>span]:size-(--event-calendar-tick) [&>span]:shrink-0 " \
                    "[&>span]:rounded-[1px] [&>span]:bg-(--event-color) " \
                    "[&>span[data-run-after]]:-me-px [&>span[data-run-after]]:rounded-r-none " \
                    "[&>span[data-run-before]]:rounded-l-none"

      # `text-foreground` rather than the muted grey it looks like it wants:
      # muted on a *selected* cell's `bg-accent` measures 4.34, and this line
      # carries information — how many events the cell did not have room for.
      MORE_CLASS = "mt-auto hidden w-full truncate text-left text-[0.7rem] font-medium " \
                   "select-none group-data-[labelled]/event-calendar:sm:block"
      # `aria-hidden`, and deliberately: the bars repeat what the day button
      # already carries in its name and what the agenda reads out in full, and a
      # screen reader hearing every event twice is worse than not seeing the
      # decoration. They are also `pointer-events-none` — one tap target per
      # day is the whole mobile-first bargain, and it holds on desktop too.
      SEGMENTS_CLASS = "pointer-events-none absolute inset-x-0 top-8 hidden auto-rows-[1.625rem] " \
                       "grid-cols-7 gap-x-px px-px group-data-[labelled]/event-calendar:sm:grid"
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
      AGENDA_TITLE_CLASS = "flex flex-wrap items-baseline gap-x-2 px-2 pb-1.5 text-sm font-medium"
      # How many, beside the date. Cheap at three events and the difference
      # between a list and a wall at sixty — a day this deep needs to say how
      # deep before you start scrolling it.
      AGENDA_COUNT_CLASS = "text-xs font-normal text-muted-foreground"
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

      # Written out rather than interpolated into `"…#\#{direction}"`, because
      # `stimulus_contract_spec` scans this file as text: an interpolated method
      # name matches nothing, so the two nav buttons were the only actions in
      # the component nothing checked. `calendar/component.rb:219` and `:291`
      # still do it the other way and are unchecked for the same reason.
      STEP_ACTIONS = {
        previous: "click->shadcn--event-calendar#previous",
        next: "click->shadcn--event-calendar#next"
      }.freeze

      default_tag :div
      slot_name :"event-calendar"

      # Every reading's tokens, and no reading's alone: a subclass adds its own
      # by redefining `style` over this. Which is the whole point of the split —
      # a plain calendar carried fifty-two `rows:` rules and twenty-two
      # `data-[track]` ones it could never fire, 74 of 94 tokens on its root.
      # What every reading wears, and nothing that only one of them can use.
      # `ROWS_TOKENS` is not here: it is the frame the workload and hours
      # readings share, and each of them adds it. A plain month carried all of
      # it — 74 of 94 tokens on its root that could never fire.
      BASE_TOKENS = "group/event-calendar w-full text-foreground #{COLOR_TOKENS}"

      style do
        base { BASE_TOKENS }
      end

      attr_reader :month, :selected, :max_events, :schedule, :reading, :group, :month_url,
                  :day_url, :day_attributes, :agenda_as, :agenda_attributes,
                  :view_url

      # The readings that are not this class. `.new` hands over to them, so a
      # host writes `Component.new(reading: :hours)` and never names a subclass
      # — the dispatcher is the constructor, not a wrapper element, so nothing
      # extra is rendered and the root stays one element.
      RENDERERS = {
        workload: "Shadcn::EventCalendar::Workload::Component",
        hours: "Shadcn::EventCalendar::Hours::Component",
        daily: "Shadcn::EventCalendar::Daily::Component"
      }.freeze

      def self.new(reading: :auto, **rest)
        renderer = RENDERERS[reading&.to_sym]

        return super(reading:, **rest) if renderer.nil? || name == renderer

        renderer.constantize.new(reading:, **rest)
      end

      # @param month [Date, nil] which month is shown; defaults to today's
      # @param selected [Date, nil] the day the agenda reads out; defaults to
      #   today when today is in view, and to the first of the month otherwise
      # @param events [Array<Hash, Event>] `{ title:, starts_at:, ends_at:,
      #   color:, url:, all_day: }` — `ends_at` is *inclusive*
      # @param max_events [Integer] bars per cell before a cell says "+2"
      # @param week_starts_on [Integer, nil] `Date#wday`; the host's
      #   `Date.beginning_of_week` when not given
      # @param day_url [#call, nil] given a `Date`, the URL of that day. Present,
      #   a cell is a link and the server owns what a click shows; absent, it is
      #   a button and the controller redraws the agenda in place.
      # @param day_attributes [Hash] merged onto every day cell — where a
      #   `data: { turbo_frame: … }` goes
      # @param group_url [#call, nil] given a grouping, the URL of that
      #   grouping. Present, the menu is links; absent, it dispatches.
      # @param show_all [Boolean] render every chip in a cell rather than the
      #   first `WORKLOAD_CAP` and a "+N"
      # @param show_all_url [#call, nil] given the desired `show_all`, the URL
      #   of that state. Present, the toggle is a link; absent, it dispatches.
      # @param agenda [Boolean] whether to render the built-in day view. `false`
      #   when the host has somewhere better to put it — a Sheet, a panel — and
      #   the day link is what fills it. It is not a leftover: it is what the
      #   *Day* tab will be made of when the toolbar grows a view switcher.
      # @param agenda_as [Symbol] the agenda's element. `:"turbo-frame"` makes
      #   the agenda itself the thing a day link swaps, without this gem
      #   mentioning Turbo anywhere.
      # @param agenda_attributes [Hash] merged onto the agenda — where its `id`
      #   goes
      # @param month_url [#call, nil] given a `Date`, the URL of that month.
      #   Present, the nav is links and the server draws the month; absent, the
      #   controller redraws it in the browser.
      # @param default_color [Symbol] the colour for events that name none —
      #   the level FullCalendar puts on an event *source*, so a calendar of one
      #   kind of thing says it once instead of on every row of a `map`
      # @param reading [Symbol] `:auto` picks bars or marks by density;
      #   `:workload` is the spike above, and always draws a row per day
      # @param arrangement [Symbol] `:auto` lets the breakpoint decide — rows
      #   below `lg`, the grid above; `:rows` keeps the rows at every width.
      #   Only the workload reading has two arrangements to pick between.
      # @param arrangement_url [#call, nil] given the desired arrangement, the
      #   URL of that state. Present, the toggle is a link; absent, it flips
      #   the attribute in the browser — which is instant, but the workload
      #   month is drawn by the server, so the next › puts it back.
      def initialize(month: nil, selected: nil, events: nil, max_events: 3,
                     week_starts_on: nil, reading: :auto,
                     default_color: :default, month_url: nil, day_url: nil,
                     day_attributes: {}, agenda: true, agenda_as: :div, agenda_attributes: {},
                     view_url: nil, **attributes)
        @month = Calendar::Month.new(month || Date.current, week_starts_on:)
        @max_events = max_events.to_i.clamp(MAX_EVENTS.first, MAX_EVENTS.last)
        @selected = (selected || default_selection).to_date
        @schedule = Schedule.new(month: @month, events:, max_lanes: @max_events, default_color:)
        # Checked against its list, like `group:` on the next line. Unchecked,
        # `reading: :workLoad` off a params hash fell through every branch and
        # rendered a silent fourth thing: no bars, no `data-labelled`, no rows.
        @month_url = month_url
        @day_url = day_url
        @day_attributes = day_attributes
        @agenda = agenda
        @agenda_as = agenda_as
        @agenda_attributes = agenda_attributes
        @reading = READINGS.include?(reading&.to_sym) ? reading.to_sym : :auto
        @reading = :auto if @reading == :events
        @view_url = view_url
        super(**attributes)
      end

      def element_attributes(**defaults)
        super(**{
          "data-controller" => "shadcn--event-calendar",
          "style" => merged_style("--event-calendar-cell:#{cell_height}rem",
                                  "--event-calendar-cell-more:#{cell_height(more: true)}rem",
                                  "--event-calendar-tick:#{tick_size}",
                                  *reading_style),
          # Read by the `sm:group-data-[overflow]` rule on the cells, and reset
          # by the controller when it draws a month with a different answer.
          "data-overflow" => ("true" if labelled? && schedule.overflow?),
          # Whether this calendar names its events or shows their shape. See
          # `#labelled?` — it is the one decision that changes what a desktop
          # cell is made of.
          "data-labelled" => ("true" if labelled?),
          **reading_attributes,
          "data-shadcn--event-calendar-month-value" => month.first.iso8601,
          # The application's today, not the browser's — the same reason the
          # calendar crosses one: `Time.zone` and a laptop's clock disagree by a
          # day for a few hours out of every twenty-four.
          "data-shadcn--event-calendar-today-value" => Date.current.iso8601,
          "data-shadcn--event-calendar-selected-value" => selected.iso8601,
          "data-shadcn--event-calendar-week-starts-on-value" => month.week_starts_on,
          "data-shadcn--event-calendar-max-events-value" => max_events,
          "data-shadcn--event-calendar-tick-sizes-value" => TICK_SIZES.to_json,
          "data-shadcn--event-calendar-dense-above-value" => DENSE_ABOVE,
          # The one constructor argument that did not cross, and both halves of
          # that were bugs: the controller re-derived `labelled` from density
          # alone, so one press of › stamped `data-labelled` on a workload
          # calendar and ran both readings at once.
          "data-shadcn--event-calendar-reading-value" => reading,
          # The order the marks band in. Crossed rather than repeated in the
          # controller for the reason everything else is: one list, in Ruby.
          "data-shadcn--event-calendar-colors-value" => Event::COLORS.to_json,
          **client_values,
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
        render_element(body: safe_join([ header, grid, (agenda if agenda?),
                                        (prototypes if client_drawn?) ].compact))
      end

      private

      # Bars and a "+N" from `sm` up, or marks at every width. Decided per
      # calendar rather than per cell, because two cells in one grid made of
      # different things would read as two kinds of day.
      def labelled? = reading == :auto && schedule.busiest <= DENSE_ABOVE

      def hours? = reading == :hours

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

      # Against the busiest day rather than against each day's own count: marks
      # of two sizes in one grid would read as two kinds of event, and the whole
      # point of the strip is that its area is comparable from cell to cell.
      def tick_size
        TICK_SIZES.find { |most, _| most.nil? || schedule.busiest <= most }.last
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
            *reading_controls,
            nav_button(Date.current, size: :sm, action: "click->shadcn--event-calendar#today") do
              shadcn_t("event_calendar.today")
            end,
            step_button(:previous),
            step_button(:next)
          ].compact),
          "data-slot": "event-calendar-nav", class: NAV_CLASS
        )
      end

      # One panel instead of three buttons that ruled each other out.
      #
      # The toolbar had a control for the view, a control for the grouping and a
      # control for the shape, and two of them were always about a view you were
      # not in — which is how it ended up drawing controls that changed nothing.
      # Here the first question is which view, and the second is the only
      # question that view has: the readings answer it themselves through
      # `#reading_options`, so no control exists for a reading that cannot act
      # on it.
      def view_panel
        render(DropdownMenu::Component.new(align: :start)) do |dropdown|
          dropdown.with_trigger(class: Button::Component.variant_classes(variant: :outline, size: :sm)) do
            safe_join([
              tag.span(view_label),
              render(Icon::Component.new("chevron-down", class: CHEVRON_CLASS))
            ])
          end
          dropdown.with_menu_content(class: "w-56") do
            safe_join([ period_options, (view_options unless daily?), *reading_options ].compact)
          end
        end
      end

      def period_options
        safe_join([
          render(DropdownMenu::Label::Component.new) { shadcn_t("event_calendar.period.label") },
          render(DropdownMenu::Separator::Component.new),
          render(DropdownMenu::RadioGroup::Component.new) do
            safe_join(PERIODS.map { |name| period_option(name) })
          end
        ])
      end

      def period_option(name)
        href = view_url&.call(name == :daily ? :daily : :grid)

        render(DropdownMenu::RadioItem::Component.new(
          value: name, checked: (name == :daily) == daily?,
          **(href ? { as: :a, href: } : { "data-action": "click->shadcn--event-calendar#changeView" })
        )) { shadcn_t("event_calendar.period.#{name}") }
      end

      def daily? = view == :daily

      def view_options
        safe_join([
          render(DropdownMenu::Label::Component.new) { shadcn_t("event_calendar.view.label") },
          render(DropdownMenu::Separator::Component.new),
          render(DropdownMenu::RadioGroup::Component.new) do
            safe_join(VIEWS.map { |name| view_option(name) })
          end
        ])
      end

      def view_option(name)
        href = view_url&.call(name)

        render(DropdownMenu::RadioItem::Component.new(
          value: name, checked: name == view,
          **(href ? { as: :a, href: } : { "data-action": "click->shadcn--event-calendar#changeView" })
        )) { shadcn_t("event_calendar.view.#{name}") }
      end

      # `:grid` is `arrangement: :auto`, not a third arrangement: below `lg` it
      # is rows anyway, because forcing seven columns onto a phone is what rows
      # were built to avoid. The name is what a person picks; `ARRANGEMENTS` is
      # what the stylesheet reads.
      def view = :grid

      # The trigger says where you are and what you are seeing — the two things
      # the panel decides, so it can be read without opening it.
      def view_label
        period = shadcn_t("event_calendar.period.#{daily? ? 'daily' : 'monthly'}")
        here = shadcn_t("event_calendar.view.#{view}") unless daily?

        safe_join([ period, here, reading_label ].compact, " · ")
      end

      def reading_label = nil

      # The second section: the one question this reading has.
      def reading_options = []

      def step_button(direction)
        target = direction == :previous ? month.previous : month.next

        nav_button(target.first, size: :"icon-sm", action: STEP_ACTIONS.fetch(direction),
                   label: shadcn_t("event_calendar.#{direction}")) do
          render(Icon::Component.new(direction == :previous ? "chevron-left" : "chevron-right",
                                     class: CHEVRON_CLASS))
        end
      end

      # A link when the caller can name the month's URL, a button otherwise.
      #
      # This is what makes the workload reading navigable at all: its cells hold
      # crews and titles that `#portable_events` does not ship, so there is
      # nothing in the browser to rebuild them from, and the controller
      # deliberately leaves them alone. Teaching the JavaScript to draw them
      # would mean shipping every assignee of every month to every page and
      # keeping a second copy of this file in JavaScript — for a reading whose
      # data is exactly what should *not* travel. A URL is the smaller and the
      # more Rails answer, and it serves the other readings too.
      def nav_button(target, size:, action:, label: nil, href: :month, pressed: nil,
                     classes: nil, value: nil, &block)
        href = month_url&.call(target) if href == :month

        render(Button::Component.new(
          # A pressed toggle is the solid button among outline ones, which is
          # what shadcn does everywhere a selection sits in a row of buttons.
          # Not `aria-pressed:bg-accent`, the shape `Toggle` uses: an outline
          # button's *hover* is already `bg-accent`, so pressed and hovered
          # would be the same picture, and an unpressed button under the mouse
          # would read as on. Borrowing a variant costs no new class, and
          # `Toggle` itself does not collide because its hover is `bg-muted`.
          variant: (pressed ? :default : :outline), size:, class: classes,
          **(href ? { as: :a, href: } : { "data-action": action }),
          "data-value": value,
          "aria-label": label,
          "aria-pressed": (pressed.to_s unless pressed.nil?)
        ).with_content(capture(&block)))
      end

      # --- the month ------------------------------------------------------------

      def grid
        tag.div(safe_join([ scale, weekdays, weeks ].compact),
                "data-slot": "event-calendar-grid", class: FRAME_CLASS)
      end

      # A reading that measures something across the month draws its scale here,
      # once, above the weeks. Nothing in this one does.
      def scale = nil

      # Custom properties a reading needs on the root, merged into `style`
      # alongside the ones every reading has.
      def reading_style = []

      # Whether the browser ever redraws this month. The events reading does —
      # its controller packs a month the server never rendered. The workload and
      # hours readings do not: their cells hold crews, clients and clock times
      # that `#portable_events` cannot carry, so the controller returns before
      # drawing and the month changes by URL.
      #
      # What that was costing was measured before it was fixed: 34 KB on a
      # workload page, 15% of it, in an events payload and a prototypes template
      # that its own controller refuses to read.
      def client_drawn? = true

      # An agenda has to be filled by whoever draws the month.
      #
      # The events reading fills it in the browser, from the crossed payload.
      # A server-drawn reading cannot: its cells hold crews and clients that
      # payload does not carry, which is the whole reason it does not ship it.
      # So there the agenda is the *server's*, and it needs `day_url:` to name
      # where a day lives — with one, the cells are links and what comes back
      # fills it; without one, there is nothing that could.
      #
      # Found by clicking a day rather than by reading the code: the suite has
      # no example that opens a workload day, so dropping the payload emptied
      # an agenda that had been working and nothing went red.
      def agenda? = @agenda && (client_drawn? || day_url.present?)

      # `data-*` a reading needs on the root for its own rules to key off.
      def reading_attributes = {}

      # What a reading adds to every day cell.
      def cell_class = nil

      # The toolbar controls a reading owns. The month nav is every reading's
      # and is not here; these are the ones only one of them can act on — which
      # is what stopped two of them being drawn where they did nothing.
      def reading_controls = []

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

      # `role="grid"` and a keyboard, which is the pattern the gem's own
      # `Calendar` implements and this one went without: forty-two tabbable
      # buttons, no arrows, no geometry. The roles describe the seven-column
      # month; below `lg` the workload reading lays the same DOM out as one row
      # per day, so what a screen reader reports and what an eye sees disagree
      # there. That is the price of one tree serving two arrangements, and it is
      # the same trade the Sidebar documents.
      def weeks
        tag.div(safe_join(schedule.weeks.map { |week| week_row(week) }),
                "data-slot": "event-calendar-weeks", class: WEEKS_CLASS,
                role: "grid",
                "aria-label": I18n.l(month.date, format: MONTH_FORMAT),
                "data-shadcn--event-calendar-target": "weeks",
                "data-action": "keydown->shadcn--event-calendar#keydown")
      end

      # `blank:` is what the `<template>` at the bottom renders through: the
      # same method, with the events left out, so the shape the controller
      # clones cannot drift from the shape the server paints.
      def week_row(week, blank: false)
        cells = week.days.map do |day|
          day_cell(day,
                   on_day: blank ? [] : schedule.on(day),
                   assignees: blank ? [] : schedule.assignees_on(day),
                   hidden: blank ? 0 : week.hidden_on(day))
        end

        tag.div(
          safe_join([
            tag.div(safe_join(cells), "data-slot": "event-calendar-days", class: DAYS_CLASS, role: "row"),
            segments(week)
          ]),
          "data-slot": "event-calendar-week", class: WEEK_CLASS, role: "presentation"
        )
      end

      # A link when the caller can name the day's URL, a button otherwise — the
      # shape `#nav_button` already has for the months. A link is the whole of
      # what a host needs to open a drawer or swap a frame: no listener, no URL
      # built by hand, and it works before the JavaScript has loaded.
      #
      # The two cannot share a gesture. With a URL the click navigates and the
      # controller's `select` is left off, so the server decides what the day
      # shows and `aria-selected` follows it.
      def day_cell(day, on_day:, assignees:, hidden:)
        href = day_url&.call(day)

        tag.public_send(href ? :a : :button,
          safe_join(cell_body(day, on_day:, assignees:, hidden:)),
          **(href ? { href: } : { type: "button", "data-action": "click->shadcn--event-calendar#select" }),
          **day_attributes,
          "data-slot": "event-calendar-day",
          class: [ DAY_CLASS, cell_class ].compact.join(" "),
          "data-day": day.iso8601,
          "data-today": ("true" if day == Date.current),
          "data-selected": ("true" if day == selected),
          "data-outside": ("true" if month.outside?(day)),
          role: "gridcell",
          # `aria-selected`, present only when true — what the gem's `Calendar`
          # writes. `aria-pressed` made every one of the other forty-one days
          # announce as "toggle button, not pressed", a state a date grid has no
          # meaning for, and it was the only non-toggle in the gem claiming it.
          "aria-selected": ("true" if day == selected),
          "aria-current": ("date" if day == Date.current),
          # One tab stop for the whole month; the arrows move within it.
          tabindex: (day == selected ? "0" : "-1"),
          "aria-label": day_label(day, on_day.size)
        )
      end


      # Every part of the cell reads the collections it was *handed*. Two of the
      # three used to go back to `schedule` for themselves, which meant
      # `week_row(blank: true)` did not blank them: the `<template>` the
      # controller clones held the first week's real people and titles, and
      # every month it drew afterwards showed August's people on September's
      # dates. A parameter nobody has to remember to use is the fix.
      # What a day is made of, which is the one thing the three readings do not
      # agree on — a list of events, a measure of work, or a timeline.
      def cell_body(day, on_day:, assignees:, hidden:)
        [ day_marker(day), ticks(on_day), more(hidden) ].compact
      end

      def day_marker(day)
        tag.span(
          safe_join([
            tag.span(I18n.t("date.abbr_day_names")[day.wday],
                     "data-slot": "event-calendar-day-weekday", class: ROWS_WEEKDAY_CLASS),
            day_number(day)
          ]),
          "data-slot": "event-calendar-day-label", class: ROWS_LABEL_CLASS
        )
      end

      def day_number(day)
        tag.span(day.day, "data-slot": "event-calendar-day-number", class: DAY_NUMBER_CLASS)
      end

      # Every event on the day, in order, as one mark each — not a sample of
      # them. A phone cell cannot hold a title, so it holds the shape of the
      # day instead: how much, of what kind, and in what order.
      #
      # `aria-hidden`, like the bars and for the same reason: the day button
      # already carries the count in its name and the agenda reads the events
      # out in full, so eighty empty spans in the accessibility tree would be
      # eighty ways to say nothing.
      #
      # `run_before`/`run_after` are read by `TICK_CLASS`. They are computed
      # here rather than with `:has(+ …)` because the controller has to compute
      # the same thing, and an attribute is the one form both sides can write.
      def ticks(on_day)
        return if on_day.empty?

        marks = in_bands(on_day)

        tag.span(
          safe_join(marks.each_with_index.map { |event, index| tick(event, marks, index) }),
          "data-slot": "event-calendar-day-ticks", class: TICKS_CLASS, "aria-hidden": "true"
        )
      end

      # Grouped by colour, in the palette's own order, and stable within each
      # group so the clock still decides the order inside a band.
      #
      # This is the one place the marks disagree with the agenda, and it was
      # measured rather than assumed: chronological marks were built first and
      # a month of them reads as confetti — at four pixels nobody can tell
      # *which* event a mark is, so ordering by time buys nothing and costs the
      # only thing a cell this size can say, which is what kind of day it is.
      # Grouped, a cell is four or five bands and two cells can be compared;
      # ordering by the palette rather than by size is what makes them
      # comparable, since a colour then sits in the same place in every cell.
      def in_bands(on_day)
        # `index` is nil for a colour outside the palette — which `Event.wrap`
        # lets through, deliberately, for an already-built Event — and a nil in
        # a sort key is a 500 rather than a bad order. Unknown sorts last, which
        # is where the JavaScript half already put it.
        on_day.sort_by.with_index { |event, index| [ Event::COLORS.index(event.color) || COLORS_END, index ] }
      end

      def tick(event, on_day, index)
        tag.span(
          "",
          "data-slot": "event-calendar-day-tick",
          "data-color": event.color,
          "data-run-before": ("true" if on_day[index - 1]&.color == event.color && index.positive?),
          "data-run-after": ("true" if on_day[index + 1]&.color == event.color)
        )
      end

      def more(count)
        return if count.zero? || !labelled?

        more_chip(count)
      end

      # Split out so the `<template>` can hold the shape unconditionally. It
      # used to go through `#more`, which returns nothing when the calendar is
      # not labelled — so a dense month shipped a prototype with no "+N" in it,
      # `this.morePrototype` was null, and the first press of › onto a month
      # that *did* overflow threw inside `replaceChildren`. The title had
      # already advanced, so every press after that threw too and the nav was
      # dead. A prototype is markup the controller may need later; whether this
      # month needs it is not the same question.
      def more_chip(count)
        tag.span(shadcn_t("event_calendar.more", count:),
                 "data-slot": "event-calendar-day-more", class: MORE_CLASS)
      end

      # The layer is rendered even when it holds nothing, because the controller
      # clones a week to draw one — but a dense calendar puts no bars in it at
      # any width, and rendering ninety-three of them to be hidden by a media
      # query is ninety-three elements nobody will ever see.
      def segments(week)
        tag.div(
          safe_join(labelled? ? week.visible.map { |segment| event_bar(segment) } : []),
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
      # The day view. With `day_url:` the server owns it — so the controller's
      # targets come off, and `agenda_as: :"turbo-frame"` lets it *be* the thing
      # a day link swaps without this gem naming Turbo anywhere.
      def agenda
        on_day = schedule.on(selected)

        tag.public_send(agenda_as,
          safe_join([
            tag.div(
              safe_join([
                tag.span(I18n.l(selected, format: agenda_format),
                         "data-shadcn--event-calendar-target": ("agendaDate" unless day_url)),
                tag.span(agenda_count(on_day.size),
                         "data-slot": "event-calendar-agenda-count", class: AGENDA_COUNT_CLASS,
                         "data-shadcn--event-calendar-target": ("agendaCount" unless day_url))
              ]),
              "data-slot": "event-calendar-agenda-title", class: AGENDA_TITLE_CLASS
            ),
            tag.ul(safe_join(on_day.map { |event| agenda_item(event) }),
                   "data-slot": "event-calendar-agenda-list", class: AGENDA_LIST_CLASS,
                   "data-shadcn--event-calendar-target": ("agendaList" unless day_url)),
            tag.p(shadcn_t("event_calendar.empty"),
                  "data-slot": "event-calendar-agenda-empty", class: AGENDA_EMPTY_CLASS,
                  hidden: on_day.any?,
                  "data-shadcn--event-calendar-target": ("agendaEmpty" unless day_url))
          ]),
          **agenda_attributes,
          "data-slot": "event-calendar-agenda", class: AGENDA_CLASS,
          role: "region",
          # The live region is the controller's: it exists because the agenda
          # changes under a pointer that never left the grid. A frame swap is a
          # navigation, and Turbo announces those itself.
          "aria-live": ("polite" unless day_url),
          "aria-label": shadcn_t("event_calendar.agenda_label")
        )
      end

      # Nothing rather than "0 events" — an empty day already says so in the
      # line underneath, and two ways of saying it is one too many.
      def agenda_count(count)
        shadcn_t("event_calendar.event_count", count:) if count.positive?
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
      # Everything the controller needs only in order to draw. A reading the
      # server draws whole ships none of it.
      def client_values
        return {} unless client_drawn?

        { "data-shadcn--event-calendar-events-value" => portable_events.to_json }
      end

      def prototypes
        tag.template(
          safe_join([
            week_row(Schedule::Week.new(days: month.weeks.first, segments: [], max_lanes: max_events),
                     blank: true),
            event_bar(Schedule::Segment.new(event: prototype_event, column: 1, span: 1, lane: 1)),
            ticks([ prototype_event ]),
            more_chip(1),
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
        # and `dayOrder` is the one a person reads a single day in.
        #
        # Ranked with an index tiebreak and keyed by position, not by object.
        # `sort_by` is not stable and `day_sort_key` ends at the title, so two
        # events differing only in colour or url ranked one way here and another
        # in `Schedule#on` — and `each_with_index.to_h` on `Event`, which defines
        # neither `#hash` nor `#eql?`, collapsed a reused instance into one key.
        ranked = schedule.events.each_with_index.sort_by { |event, index| [ *event.day_sort_key, index ] }
        day_order = ranked.each_with_index.to_h { |(_, original), rank| [ original, rank ] }

        schedule.events.each_with_index.map do |event, index|
          # Bound once each. `chip_time` was called four times and `agenda_meta`
          # twice per event, and on a month of two thousand that measured 117 ms
          # of a 155 ms render.
          time = chip_time(event)
          meta = agenda_meta(event)

          {
            id: event.id,
            dayOrder: day_order[index],
            title: event.title,
            color: event.color,
            from: event.start_date.iso8601,
            # Only what differs from what can be worked out. At this component's
            # thin end that saves nothing; at the dense one it is a third of a
            # megabyte, because every key is paid for two thousand times. The
            # controller fills each of these back in — see `eventsValueChanged`.
            to: (event.end_date.iso8601 unless event.end_date == event.start_date),
            allDay: (true if event.all_day?),
            time:,
            meta: (meta unless meta == time),
            url: event.url.presence
          }.compact
        end
      end

      def chip_time(event)
        return if event.all_day? || !event.starts_at.respond_to?(:hour)

        I18n.l(event.starts_at, format: time_format)
      end

      # The agenda's second line: a clock for a timed event, the span for one
      # that crosses days, and the words for an all-day one.
      def agenda_meta(event)
        return date_span(event) if event.multi_day?
        return shadcn_t("event_calendar.all_day") if event.all_day?
        return chip_time(event) if event.ends_at.blank? || !event.ends_at.respond_to?(:hour)

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
