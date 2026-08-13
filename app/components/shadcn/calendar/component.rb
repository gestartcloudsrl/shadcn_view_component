# frozen_string_literal: true

module Shadcn
  module Calendar
    # Port of registry/new-york-v4/ui/calendar.tsx.
    #
    # Upstream is 220 lines that hand every class to `react-day-picker` and let
    # it render — so the class map is fully specified there, and the markup is
    # the package's. That markup is a plain `<table role="grid">`, which is why
    # this port has no dependency: what the package mostly *is* — 3,479 lines of
    # locale data, 2,046 of Ethiopic, Hebrew, Hijri, Persian and Jalali
    # calendars, and 576 wrapping `date-fns` — a Rails app already has in `Date`
    # and `I18n`. See [features/calendar.md](../../../../.claude/docs/features/calendar.md).
    #
    # The grid is computed in `Calendar::Month` and rendered here, so a calendar
    # is readable with no JavaScript at all — the one family in this gem where
    # that is true of the whole component rather than of its resting state.
    class Component < ApplicationViewComponent
      # Upstream writes these two with `String.raw`, so the backslash is part of
      # the class. Single-quoted here for the same reason: in a double-quoted
      # Ruby string `\_` is just `_`, and the token would stop matching the
      # element it names.
      RTL_CHEVRONS = 'rtl:**:[.rdp-button\_next>svg]:rotate-180 rtl:**:[.rdp-button\_previous>svg]:rotate-180'

      # The two `rdp-*` classes this port does render, and the only ones. They
      # are not styling — they are what the two `RTL_CHEVRONS` selectors above
      # point at, and upstream's own rule would match nothing without them.
      # Every other `rdp-*` name comes from `getDefaultClassNames()`, a function
      # call rather than a string in the vendored source, and nothing here
      # styles them.
      PREVIOUS_CLASS = "rdp-button_previous"
      NEXT_CLASS = "rdp-button_next"

      MODES = %i[single multiple range].freeze
      CAPTION_LAYOUTS = %i[label dropdown dropdown_months dropdown_years].freeze

      MONTHS_CLASS = "relative flex flex-col gap-4 md:flex-row"
      MONTH_CLASS = "flex w-full flex-col gap-4"
      NAV_CLASS = "absolute inset-x-0 top-0 flex w-full items-center justify-between gap-1"
      CAPTION_CLASS = "flex h-(--cell-size) w-full items-center justify-center px-(--cell-size)"
      CAPTION_LABEL_CLASS = "font-medium select-none"
      CAPTION_LABEL_LABEL_CLASS = "text-sm"
      CAPTION_LABEL_DROPDOWN_CLASS = "flex h-8 items-center gap-1 rounded-md pr-1 pl-2 text-sm " \
                                     "[&>svg]:size-3.5 [&>svg]:text-muted-foreground"
      DROPDOWNS_CLASS = "flex h-(--cell-size) w-full items-center justify-center gap-1.5 text-sm font-medium"
      DROPDOWN_ROOT_CLASS = "relative rounded-md border border-input shadow-xs has-focus:border-ring " \
                            "has-focus:ring-[3px] has-focus:ring-ring/50"
      DROPDOWN_CLASS = "absolute inset-0 bg-popover opacity-0"
      # What a screen reader is left with once the caption is two dropdowns: the
      # month has to be announced when it changes, and the dropdowns announce
      # themselves as controls rather than as the answer. Upstream's own inline
      # style, which is `sr-only` written out.
      STATUS_STYLE = "border:0;clip:rect(0 0 0 0);height:1px;margin:-1px;overflow:hidden;padding:0;" \
                     "position:absolute;width:1px;white-space:nowrap;word-wrap:normal"
      GRID_CLASS = "w-full border-collapse"
      WEEKDAYS_CLASS = "flex"
      WEEKDAY_CLASS = "flex-1 rounded-md text-[0.8rem] font-normal text-muted-foreground select-none"
      WEEK_CLASS = "mt-2 flex w-full"
      WEEK_NUMBER_HEADER_CLASS = "w-(--cell-size) select-none"
      WEEK_NUMBER_CLASS = "text-[0.8rem] text-muted-foreground select-none"
      WEEK_NUMBER_INNER_CLASS = "flex size-(--cell-size) items-center justify-center text-center"
      DAY_CLASS = "group/day relative aspect-square h-full w-full p-0 text-center select-none " \
                  "[&:last-child[data-selected=true]_button]:rounded-r-md"
      DAY_FIRST_CLASS = "[&:first-child[data-selected=true]_button]:rounded-l-md"
      DAY_FIRST_WITH_WEEK_NUMBER_CLASS = "[&:nth-child(2)[data-selected=true]_button]:rounded-l-md"
      TODAY_CLASS = "rounded-md bg-accent text-accent-foreground data-[selected=true]:rounded-none"
      OUTSIDE_CLASS = "text-muted-foreground aria-selected:text-muted-foreground"
      DISABLED_CLASS = "text-muted-foreground opacity-50"
      HIDDEN_CLASS = "invisible"
      RANGE_START_CLASS = "rounded-l-md bg-accent"
      RANGE_MIDDLE_CLASS = "rounded-none"
      RANGE_END_CLASS = "rounded-r-md bg-accent"
      NAV_BUTTON_CLASS = "size-(--cell-size) p-0 select-none aria-disabled:opacity-50"
      DAY_BUTTON_CLASS = "flex aspect-square size-auto w-full min-w-(--cell-size) flex-col gap-1 leading-none " \
                         "font-normal group-data-[focused=true]/day:relative group-data-[focused=true]/day:z-10 " \
                         "group-data-[focused=true]/day:border-ring group-data-[focused=true]/day:ring-[3px] " \
                         "group-data-[focused=true]/day:ring-ring/50 data-[range-end=true]:rounded-md " \
                         "data-[range-end=true]:rounded-r-md data-[range-end=true]:bg-primary " \
                         "data-[range-end=true]:text-primary-foreground data-[range-middle=true]:rounded-none " \
                         "data-[range-middle=true]:bg-accent data-[range-middle=true]:text-accent-foreground " \
                         "data-[range-start=true]:rounded-md data-[range-start=true]:rounded-l-md " \
                         "data-[range-start=true]:bg-primary data-[range-start=true]:text-primary-foreground " \
                         "data-[selected-single=true]:bg-primary data-[selected-single=true]:text-primary-foreground " \
                         "dark:hover:text-accent-foreground [&>span]:text-xs [&>span]:opacity-70"
      CHEVRON_CLASS = "size-4"

      default_tag :div
      slot_name :calendar

      style do
        base {
          "w-fit group/calendar bg-background p-3 [--cell-size:--spacing(8)] " \
          "[[data-slot=card-content]_&]:bg-transparent [[data-slot=popover-content]_&]:bg-transparent " +
            RTL_CHEVRONS
        }
      end

      attr_reader :month, :months, :number_of_months, :mode, :selected, :disabled,
                  :button_variant, :caption_layout, :name, :required,
                  :show_outside_days, :show_week_number, :fixed_weeks,
                  :start_month, :end_month, :week_starts_on

      # `month:` is which month is shown, `selected:` what is chosen in it, and
      # they are separate on purpose — upstream's `month` and `selected` are two
      # props for the same reason: a range can end in a month nobody is looking
      # at.
      #
      # `disabled:` takes anything that answers `===` — a Date, a Range, a
      # lambda — or an array of those. That is Ruby's own matcher protocol, and
      # it covers what upstream's `Matcher` union covers without inventing a
      # shape for it.
      def initialize(month: nil, mode: :single, selected: nil, disabled: nil, name: nil, required: false,
                     caption_layout: :label, button_variant: :ghost, show_outside_days: true,
                     show_week_number: false, fixed_weeks: false, number_of_months: 1,
                     start_month: nil, end_month: nil, week_starts_on: nil,
                     **attributes)
        @mode = MODES.include?(mode&.to_sym) ? mode.to_sym : :single
        @selected = Array(selected.is_a?(Range) ? [ selected.begin, selected.end ] : selected).compact.map(&:to_date)
        # A range arrives either as a `Range` or as the two ends of one, because
        # that is what comes back from the controller and from a form. Both mean
        # the same thing here, and the modifier classes read this rather than
        # the argument's shape.
        @range = if selected.is_a?(Range) then selected.begin.to_date..selected.end.to_date
        elsif @mode == :range && @selected.size == 2 then @selected.first..@selected.last
        end
        @disabled = disabled
        @name = name
        @required = required
        @caption_layout = CAPTION_LAYOUTS.include?(caption_layout&.to_sym) ? caption_layout.to_sym : :label
        @button_variant = button_variant&.to_sym || :ghost
        @show_outside_days = show_outside_days
        @show_week_number = show_week_number
        @fixed_weeks = fixed_weeks
        @number_of_months = [ number_of_months.to_i, 1 ].max
        @start_month = start_month&.to_date
        @end_month = end_month&.to_date
        @week_starts_on = week_starts_on
        @month = Month.new(month || @selected.first || Date.current,
                           week_starts_on:, fixed_weeks:)
        # Upstream's `numberOfMonths`: one nav for the lot, and a caption and a
        # grid each. The months run forward from the one that was asked for.
        @months = Array.new(@number_of_months) { |offset| offset.zero? ? @month : @month.plus_months(offset) }
        super(**attributes)
      end

      # Everything the controller needs to draw a month the server never
      # rendered, and nothing else. The names, the formats and the modifier
      # classes all cross from here rather than being written in JavaScript:
      # `I18n` stays the only thing that decides how a date reads, and Tailwind
      # only ever sees a class in Ruby source.
      def element_attributes(**defaults)
        super(**{
          "data-controller" => "shadcn--calendar",
          "data-shadcn--calendar-month-value" => month.first.iso8601,
          "data-shadcn--calendar-today-value" => Date.current.iso8601,
          "data-shadcn--calendar-week-starts-on-value" => month.week_starts_on,
          "data-shadcn--calendar-fixed-weeks-value" => fixed_weeks,
          "data-shadcn--calendar-show-outside-days-value" => show_outside_days,
          "data-shadcn--calendar-show-week-number-value" => show_week_number,
          "data-shadcn--calendar-start-month-value" => start_month&.beginning_of_month&.iso8601,
          "data-shadcn--calendar-end-month-value" => end_month&.end_of_month&.iso8601,
          "data-shadcn--calendar-mode-value" => mode,
          "data-shadcn--calendar-required-value" => required,
          "data-shadcn--calendar-input-names-value" => input_names.to_json,
          "data-shadcn--calendar-selected-value" => selected_dates.to_json,
          "data-shadcn--calendar-disabled-value" => portable_matchers.to_json,
          "data-shadcn--calendar-day-names-value" => day_names.to_json,
          "data-shadcn--calendar-short-day-names-value" => short_day_names.to_json,
          "data-shadcn--calendar-month-names-value" => month_names.to_json,
          "data-shadcn--calendar-short-month-names-value" => short_month_names.to_json,
          "data-shadcn--calendar-date-format-value" => day_label_format,
          "data-shadcn--calendar-month-format-value" => MONTH_FORMAT,
          # Fetched with the placeholder as its own argument, so what crosses is
          # the template rather than a rendered sentence — `I18n` raises on a
          # missing interpolation and the controller needs the `%{date}` intact.
          "data-shadcn--calendar-today-label-value" => shadcn_t("calendar.today_label", date: "%{date}"),
          "data-shadcn--calendar-selected-label-value" => shadcn_t("calendar.selected_label", date: "%{date}"),
          "data-shadcn--calendar-week-number-label-value" => shadcn_t("calendar.week_number", number: "%{number}"),
          "data-shadcn--calendar-today-class-value" => TODAY_CLASS,
          "data-shadcn--calendar-outside-class-value" => OUTSIDE_CLASS,
          "data-shadcn--calendar-disabled-class-value" => DISABLED_CLASS,
          "data-shadcn--calendar-hidden-class-value" => HIDDEN_CLASS,
          "data-shadcn--calendar-range-start-class-value" => RANGE_START_CLASS,
          "data-shadcn--calendar-range-middle-class-value" => RANGE_MIDDLE_CLASS,
          "data-shadcn--calendar-range-end-class-value" => RANGE_END_CLASS
        }.compact.merge(defaults))
      end

      def call
        # Block content lands after the months, which is where upstream's
        # `footer` prop renders — and inside the root, which is what lets a
        # preset button's `data-action` reach this controller at all.
        render_element(body: safe_join([
          tag.div(safe_join([ nav, *months.map { |shown| month_body(shown) } ]), class: MONTHS_CLASS),
          inputs,
          content
        ].compact))
      end

      private

      # The nav sits over the caption rather than beside it — `absolute` on the
      # nav, and the caption padded by a cell on each side to leave room.
      # `labelNav()` returns an empty string upstream, and an empty `aria-label`
      # names nothing, so this port leaves the attribute off rather than
      # rendering one that does no work.
      def nav
        tag.nav(safe_join([ step_button(:previous), step_button(:next) ]), class: NAV_CLASS)
      end

      def step_button(direction)
        target = direction == :previous ? month.previous : month.next
        unavailable = out_of_bounds?(target.first)

        tag.button(
          render(Icon::Component.new("chevron-#{direction == :previous ? 'left' : 'right'}", class: CHEVRON_CLASS)),
          type: "button",
          "data-shadcn--calendar-target": direction,
          "data-action": "click->shadcn--calendar##{direction}",
          class: Button::Component.variant_classes(
            variant: button_variant,
            class: [ NAV_BUTTON_CLASS, direction == :previous ? PREVIOUS_CLASS : NEXT_CLASS ].join(" ")
          ),
          tabindex: ("-1" if unavailable),
          "aria-disabled": ("true" if unavailable),
          "aria-label": shadcn_t("calendar.#{direction}")
        )
      end

      def month_body(shown)
        tag.div(safe_join([ caption(shown), grid(shown) ]), class: MONTH_CLASS)
      end

      # `role="status"` with `aria-live="polite"`, as upstream's CaptionLabel
      # carries: the month is the one thing on the page that changes when the
      # nav is pressed, and a screen reader has to hear it without being moved.
      def caption(shown)
        tag.div(caption_layout == :label ? plain_caption(shown) : dropdown_caption(shown), class: CAPTION_CLASS)
      end

      def plain_caption(shown)
        tag.span(label_of(shown), class: "#{CAPTION_LABEL_CLASS} #{CAPTION_LABEL_LABEL_CLASS}",
                 id: caption_id(shown), role: "status", "aria-live": "polite",
                 "data-shadcn--calendar-target": "caption")
      end

      # Two native `<select>`s, laid invisible over the label they change — the
      # same technique the one-time-code field uses, and upstream's here: the
      # control a person operates is the real one, and what they read is the
      # `aria-hidden` span underneath it.
      def dropdown_caption(shown)
        controls = [
          (month_dropdown(shown) if caption_layout != :dropdown_years),
          (tag.span(I18n.l(shown.date, format: "%b")) if caption_layout == :dropdown_years),
          (year_dropdown(shown) if caption_layout != :dropdown_months),
          (tag.span(shown.date.year) if caption_layout == :dropdown_months)
        ].compact

        tag.div(
          safe_join(controls + [ tag.span(label_of(shown), id: caption_id(shown), role: "status",
                                          "aria-live": "polite", style: STATUS_STYLE,
                                          "data-shadcn--calendar-target": "caption") ]),
          class: DROPDOWNS_CLASS
        )
      end

      def month_dropdown(shown)
        options = (1..12).map do |number|
          { value: number, label: I18n.t("date.abbr_month_names")[number] }
        end

        dropdown(options, shown.date.month, shadcn_t("calendar.choose_month"), :monthSelect, :chooseMonth)
      end

      def year_dropdown(shown)
        first = (start_month || shown.date - 100.years).year
        last = (end_month || shown.date + 100.years).year
        options = (first..last).map { |year| { value: year, label: year.to_s } }

        dropdown(options, shown.date.year, shadcn_t("calendar.choose_year"), :yearSelect, :chooseYear)
      end

      def dropdown(options, value, label, target, action)
        tag.span(
          safe_join([
            tag.select(
              safe_join(options.map { |option| tag.option(option[:label], value: option[:value], selected: option[:value] == value) }),
              class: DROPDOWN_CLASS,
              "aria-label": label,
              "data-shadcn--calendar-target": target,
              "data-action": "change->shadcn--calendar##{action}"
            ),
            tag.span(
              safe_join([
                options.find { |option| option[:value] == value }&.dig(:label),
                render(Icon::Component.new("chevron-down", class: CHEVRON_CLASS))
              ].compact),
              class: "#{CAPTION_LABEL_CLASS} #{CAPTION_LABEL_DROPDOWN_CLASS}",
              "aria-hidden": "true"
            )
          ]),
          class: DROPDOWN_ROOT_CLASS
        )
      end

      # The grid is the control, so a caller who names this component names the
      # *table* — and keeps the month, which is the other half of what a screen
      # reader needs here. `aria-labelledby` wins over `aria-label` outright, so
      # the two are combined by id rather than left to fight: "Starts on,
      # August 2026".
      def grid(shown)
        tag.table(
          safe_join([ weekday_header(shown), weeks(shown) ]),
          class: GRID_CLASS,
          role: "grid",
          "data-shadcn--calendar-target": "grid",
          "data-action": "keydown->shadcn--calendar#keydown focusin->shadcn--calendar#focused",
          "aria-multiselectable": ("true" if mode != :single),
          "aria-labelledby": "#{attributes[:"aria-labelledby"]} #{caption_id(shown)}".strip,
          "aria-label": (label_of(shown) if attributes[:"aria-labelledby"].blank?)
        )
      end

      def caption_id(shown)
        @caption_ids ||= Hash.new { |ids, key| ids[key] = "shadcn-calendar-caption-#{SecureRandom.hex(4)}" }
        @caption_ids[shown.first]
      end

      # `aria-hidden` on the whole header row, which is upstream's: the day
      # names repeat in every cell's own label, so a screen reader reading the
      # grid would say each one eight times.
      def weekday_header(shown)
        cells = shown.weekday_numbers.map do |number|
          tag.th(short_day_names[number], class: WEEKDAY_CLASS, scope: "col",
                 "aria-label": day_names[number])
        end
        if show_week_number
          # No text and a name of its own: upstream's `formatWeekNumberHeader`
          # returns an empty string and the column is named by its `aria-label`.
          cells.unshift(tag.th(nil, class: WEEK_NUMBER_HEADER_CLASS, scope: "col",
                               "aria-label": shadcn_t("calendar.week_number_header")))
        end

        tag.thead(tag.tr(safe_join(cells), class: WEEKDAYS_CLASS), "aria-hidden": "true")
      end

      def weeks(shown)
        tag.tbody(safe_join(shown.weeks.map { |week| week_row(week, shown) }),
                  "data-shadcn--calendar-target": "weeks")
      end

      def week_row(week, shown)
        cells = week.map { |day| day_cell(day, shown) }
        cells.unshift(week_number_cell(week, shown)) if show_week_number

        tag.tr(safe_join(cells), class: WEEK_CLASS)
      end

      # A `<td>`, not the `<th>` the package renders: `calendar.tsx` overrides
      # `WeekNumber` with one (calendar.tsx:167-175), and the `scope` and role
      # come from DayPicker either way.
      def week_number_cell(week, shown)
        number = shown.number_of(week)

        tag.td(
          tag.div(number, class: WEEK_NUMBER_INNER_CLASS),
          class: WEEK_NUMBER_CLASS, scope: "row", role: "rowheader",
          "aria-label": shadcn_t("calendar.week_number", number:)
        )
      end

      # The cell carries the state and the button carries the label: upstream
      # puts `data-selected`, `data-today` and the rest on the `<td>`, and the
      # classes that read them are written against that.
      def day_cell(day, shown)
        outside = shown.outside?(day)
        hidden = outside && !show_outside_days

        tag.td(
          (day_button(day, shown) unless hidden),
          class: day_classes(day, outside:, hidden:),
          role: "gridcell",
          "data-day": day.iso8601,
          "data-month": (day.strftime("%Y-%m") if outside),
          "data-outside": ("true" if outside),
          "data-today": ("true" if day == Date.current),
          "data-selected": ("true" if selected?(day)),
          "data-disabled": ("true" if disabled?(day)),
          "data-hidden": ("true" if hidden),
          "aria-selected": ("true" if selected?(day))
        )
      end

      def day_classes(day, outside:, hidden:)
        [
          DAY_CLASS,
          show_week_number ? DAY_FIRST_WITH_WEEK_NUMBER_CLASS : DAY_FIRST_CLASS,
          (TODAY_CLASS if day == Date.current),
          (OUTSIDE_CLASS if outside),
          (DISABLED_CLASS if disabled?(day)),
          (HIDDEN_CLASS if hidden),
          (RANGE_START_CLASS if range_start?(day)),
          (RANGE_MIDDLE_CLASS if range_middle?(day)),
          (RANGE_END_CLASS if range_end?(day))
        ].compact.join(" ")
      end

      # A real `Button`, as upstream's `CalendarDayButton` is — so it carries
      # `data-slot="button"` and the variant classes rather than a copy of them.
      #
      # `data-day` here is the *formatted* date where the cell's is ISO, which
      # is upstream's split too (`day.date.toLocaleDateString()` against
      # `day.isoDate`). The machine-readable one is the cell's.
      def day_button(day, shown)
        render(Button::Component.new(
          variant: :ghost,
          size: :icon,
          class: DAY_BUTTON_CLASS,
          type: "button",
          disabled: disabled?(day),
          tabindex: (focus_target?(day, shown) ? "0" : "-1"),
          "data-action": "click->shadcn--calendar#select",
          "data-day": I18n.l(day, format: :default),
          "data-selected-single": ("true" if mode == :single && selected?(day)),
          "data-range-start": ("true" if range_start?(day)),
          "data-range-middle": ("true" if range_middle?(day)),
          "data-range-end": ("true" if range_end?(day)),
          "aria-label": day_label(day)
        )) { day.day.to_s }
      end

      # Exactly one day in the grid is tabbable, and the rest are reached with
      # the arrow keys — the grid pattern, and what upstream's `isFocusTarget`
      # does. The selected day if it is here, otherwise today, otherwise the
      # first day of the month.
      #
      # A disabled candidate is passed over rather than taken: a tab stop on a
      # disabled button is no tab stop at all, and the grid would drop out of
      # the tab order for a calendar whose selected day happens to be blocked.
      # The controller repeats this rule after every re-render, because a month
      # with nothing tabbable is a month the keyboard cannot reach.
      # One tab stop per grid, so a two-month calendar has two — each grid is a
      # `role="grid"` of its own and the arrows walk between them by date.
      def focus_target(shown)
        @focus_targets ||= {}
        @focus_targets[shown.first] ||= [
          selected.find { |date| shown.days.include?(date) },
          (Date.current if shown.days.include?(Date.current)),
          shown.first
        ].compact.find { |date| !disabled?(date) } || shown.first
      end

      def focus_target?(day, shown) = day == focus_target(shown)

      def selected?(day)
        return @range.cover?(day) if @range

        selected.include?(day)
      end

      def range_start?(day) = @range && day == @range.begin
      def range_end?(day) = @range && day == @range.end
      def range_middle?(day) = @range && @range.cover?(day) && day != @range.begin && day != @range.end

      def disabled?(day)
        out_of_bounds?(day) || Array.wrap(disabled).any? { |matcher| matcher === day } # rubocop:disable Style/CaseEquality
      end

      def out_of_bounds?(day)
        (start_month && day.end_of_month < start_month.beginning_of_month) ||
          (end_month && day.beginning_of_month > end_month.end_of_month)
      end

      MONTH_FORMAT = "%B %Y"

      # What a Rails form receives. One input per value, named the way the mode
      # means it:
      #
      # | `mode:`     | `name: "trip[on]"` becomes            |
      # |-------------|---------------------------------------|
      # | `:single`   | `trip[on]`                            |
      # | `:multiple` | `trip[on][]`, one per day             |
      # | `:range`    | `trip[on][from]` and `trip[on][to]`   |
      #
      # A range can also be given two names of its own —
      # `name: %w[trip[from] trip[to]]` — because two dates are usually two
      # columns, and `starts_on`/`ends_on` is what a Rails model calls them.
      #
      # An empty value is still submitted, so that clearing a date reaches the
      # controller: a parameter that simply vanishes leaves the old value in
      # place, which is the same trap Rails' own checkbox hidden field exists to
      # avoid.
      def inputs
        return if input_names.empty?

        tag.span(safe_join(input_values.map { |field, value|
          tag.input(type: "hidden", name: field, value:, autocomplete: "off")
        }), "data-shadcn--calendar-target": "inputs")
      end

      def input_names
        return [] if name.blank?
        return Array(name) if name.is_a?(Array)

        case mode
        when :multiple then [ "#{name}[]" ]
        when :range then [ "#{name}[from]", "#{name}[to]" ]
        else [ name.to_s ]
        end
      end

      def input_values
        return input_names.zip(selected.map(&:iso8601)).map { |field, value| [ field, value.to_s ] } if mode == :range

        return [ [ input_names.first, "" ] ] if selected.empty?

        selected.map { |date| [ input_names.first, date.iso8601 ] }
      end

      def label_of(shown) = I18n.l(shown.date, format: MONTH_FORMAT)

      # The two lists as the controller indexes them: weekdays by `Date#wday`,
      # months from zero, which is what `getDay()` and `getMonth()` hand back.
      def month_names = I18n.t("date.month_names").compact
      def short_month_names = I18n.t("date.abbr_month_names").compact

      def selected_dates = selected.map(&:iso8601)

      # A `Date` and a `Range` of them cross to the browser as themselves. A
      # callable cannot — it decided the month the server rendered, and says
      # nothing about a month reached from the nav. Named here rather than left
      # to be discovered; see features/calendar.md.
      def portable_matchers
        Array.wrap(disabled).filter_map do |matcher|
          case matcher
          when Date then matcher.iso8601
          when Range then { from: matcher.begin&.to_date&.iso8601, to: matcher.end&.to_date&.iso8601 }
          end
        end
      end

      # One pattern, localized once and then handed to the controller as text —
      # rather than a weekday glued onto a formatted date on one side and not
      # the other, which is how the two first disagreed.
      def day_label_format = "%A, #{I18n.t('date.formats.long')}"

      def day_label(day)
        label = I18n.l(day, format: day_label_format)
        label = shadcn_t("calendar.today_label", date: label) if day == Date.current
        label = shadcn_t("calendar.selected_label", date: label) if selected?(day)
        label
      end

      def day_names = I18n.t("date.day_names")
      def short_day_names = I18n.t("date.abbr_day_names")
    end
  end
end
