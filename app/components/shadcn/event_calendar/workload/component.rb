# frozen_string_literal: true

module Shadcn
  module EventCalendar
    module Workload
      # A month read as a **quantity**: how much work each day holds, and whose.
      #
      # A cell is a measure rather than a list — the day's total on a heat ramp,
      # then a chip per operator or per intervention. The events reading answers
      # "what is on", this one answers "how loaded", and `Hours::Component`
      # answers "when" — see `Chips` for the one thing this and hours share.
      #
      # A host never names this class: `EventCalendar::Component.new(reading:
      # :workload)` hands over to it.
      class Component < EventCalendar::Component
        include Chips

        attr_reader :group, :group_url, :show_all, :show_all_url, :arrangement

        # @param group [Symbol] `:events` — a chip per intervention, which is
        #   what a day's work actually is — or `:assignees`, a chip per operator
        #   with their count.
        # @param show_all [Boolean] render every chip rather than the first
        #   `CAP` and a "+N". Server state, not a class toggle: rendering them
        #   all and hiding the rest cost 1157 KB and 131 ms on 447 events.
        # @param arrangement [Symbol] `:auto` lets the breakpoint decide — rows
        #   below `lg`, the grid above; `:rows` keeps the rows at every width.
        # @param group_url [#call, nil] given a grouping, the URL of that state
        # @param show_all_url [#call, nil] given the wanted `show_all`, its URL
        def initialize(group: :events, group_url: nil, show_all: false, show_all_url: nil,
                       arrangement: :auto, **attributes)
          @group = GROUPINGS.include?(group&.to_sym) ? group.to_sym : :events
          @group_url = group_url
          @show_all = show_all
          @show_all_url = show_all_url
          @arrangement = EventCalendar::Component::ARRANGEMENTS.include?(arrangement&.to_sym) ? arrangement.to_sym : :auto
          super(**attributes)
        end

        # The horizontal strip a row's chips scroll in, and the `shrink-0` that
        # makes them overflow rather than squash — without which the strip never
        # scrolled at all, measured as `scrollWidth === clientWidth`.
        #
        # These stayed behind when the frame rules went to `ROWS_TOKENS`,
        # because hours lays its chips out by the clock and has no strip. One
        # rule went nowhere: `rows:…day-ticks:block` could not fire, since ticks
        # are the events reading's and `rows:` needs `data-rows`, which only
        # these two set.
        STRIP_TOKENS =
          "rows:[&_[data-slot=event-calendar-day-assignees]]:w-auto " \
          "rows:[&_[data-slot=event-calendar-day-assignees]]:flex-row " \
          "rows:[&_[data-slot=event-calendar-day-assignees]]:flex-nowrap " \
          "rows:[&_[data-slot=event-calendar-day-assignees]]:overflow-x-auto " \
          "rows:[&_[data-slot=event-calendar-day-assignees]]:overscroll-x-contain " \
          "rows:[&_[data-slot=event-calendar-day-assignees]]:touch-pan-x " \
          "rows:[&_[data-slot=event-calendar-day-assignees]]:[scrollbar-width:none] " \
          "rows:[&_[data-slot=event-calendar-day-assignees]]:[&::-webkit-scrollbar]:hidden " \
          "rows:[&_[data-slot=event-calendar-day-assignees]]:min-w-0 " \
          "rows:[&_[data-slot=event-calendar-day-items]]:w-auto " \
          "rows:[&_[data-slot=event-calendar-day-items]]:flex-row " \
          "rows:[&_[data-slot=event-calendar-day-items]]:flex-nowrap " \
          "rows:[&_[data-slot=event-calendar-day-items]]:overflow-x-auto " \
          "rows:[&_[data-slot=event-calendar-day-items]]:overscroll-x-contain " \
          "rows:[&_[data-slot=event-calendar-day-items]]:touch-pan-x " \
          "rows:[&_[data-slot=event-calendar-day-items]]:[scrollbar-width:none] " \
          "rows:[&_[data-slot=event-calendar-day-items]]:[&::-webkit-scrollbar]:hidden " \
          "rows:[&_[data-slot=event-calendar-day-items]]:min-w-0"

        def client_drawn? = false

        def cell_class = CELL_CLASS

        def reading_attributes
          { "data-group" => group, "data-rows" => "true", "data-arrangement" => arrangement }
        end

        # `:grid` and `:rows` are this reading at its two arrangements, and the
        # panel offers them beside the hours view because a person is picking
        # one thing. The standalone toggle that used to do it is gone with the
        # button: two controls for one question is what the panel replaced.
        def view = arrangement == :rows ? :rows : :grid

        def reading_controls = [ view_panel, show_all_toggle ]

        def reading_label = shadcn_t("event_calendar.group.#{group}")

        def reading_options = [ grouping_items ]

        style do
          base { "#{EventCalendar::Component::BASE_TOKENS} #{EventCalendar::Component::ROWS_TOKENS} " \
                 "#{STRIP_TOKENS} #{STRIP_CHIP_TOKENS}" }
        end

        GROUPINGS = %i[assignees events].freeze
        # How many chips a cell shows before it says "+N", and how many it
        # *renders*. Those used to be different numbers: every chip was rendered
        # and CSS hid the fourth onwards, so "Show all" could be a class toggle.
        # Measured on a month of 447 events that cost 1157 KB of HTML and 131 ms
        # of render for ninety-three visible chips — 1136 avatar components, of
        # which eight hundred were never seen. Capping the render is 451 KB and
        # 74 ms.
        #
        # So "Show all" is state now, like `group:` and `month:`: `show_all:`
        # comes in, and the toggle is a link when the caller can name the URL of
        # the other state. That is the same bargain the nav makes, and this
        # reading is server-drawn anyway.

        # How many chips a cell shows before it says "+N", and how many it
        # *renders*. Those used to be different numbers: every chip was rendered
        # and CSS hid the fourth onwards, so "Show all" could be a class toggle.
        # Measured on a month of 447 events that cost 1157 KB of HTML and 131 ms
        # of render for ninety-three visible chips — 1136 avatar components, of
        # which eight hundred were never seen. Capping the render is 451 KB and
        # 74 ms.
        #
        # So "Show all" is state now, like `group:` and `month:`: `show_all:`
        # comes in, and the toggle is a link when the caller can name the URL of
        # the other state. That is the same bargain the nav makes, and this
        # reading is server-drawn anyway.
        CAP = 3

        # ---- rows-are-days --------------------------------------------------
        #
        # Below `lg` the workload reading is one row per day: a fixed date column
        # on the left, the day's chips scrolling to the right. From `lg` up it is
        # the seven-column month again.
        #
        # Which arrangement is a *width* decision and not an argument. `layout:`
        # existed for a while and was the wrong shape: a server cannot know the
        # viewport, so the choice was never the caller's to make.
        #
        # Declared here as descendant rules on the root, the way `COLOR_TOKENS`
        # is, rather than as a variant chain on each of eight elements — and each
        # one on a single line, because a token split across a `\` continuation
        # is two halves that match nothing. That has already cost one silent
        # failure in this file.
        #
        # `rows:` is the gem's own variant, declared in `shadcn.css` beside
        # `dark`. It stands for *narrow or told to*: below `lg`, or at any width
        # once the toolbar has set `data-arrangement="rows"`. It exists because
        # these rules had been written as `max-lg:data-[rows]:` — a media query,
        # which no button can reach. Writing each rule twice would have been
        # fifty-two more tokens to keep in step; a variant is one name and the
        # list below is unchanged.
        #
        # The whole switch is `display: contents` on the week and on its
        # seven-column grid: with neither box in the way, the day buttons become
        # children of the weeks column and lay themselves out as rows.
        #
        # Some of the rules give back what the phone's *grid* had to drop from an
        # intervention chip — the clock with its minutes and meridiem, and the
        # crew — because a row is not a 46px cell and has room for all of it.
        #
        # The rest build the date column. In the grid the head is a line: number
        # on the left, count badge on the right. In a row it is a stack — weekday
        # small, day large, count under both — so `contents` gives way to a real
        # `w-14` box and the badge stops being pushed to the far end. That is what
        # takes a row from 44px to 72px, and it is the whole cost of the change:
        # the month goes from about 1400px tall to about 2200px.
        #
        # No comments inside the list below, however tempting. A comment line
        # between two `\` continuations does not interrupt the expression, it
        # *ends the string*: `"a " \` + comment + `"b"` is `"a "`, silently, and
        # rubocop reports nothing. Three of these rules were lost that way.

        # A chip is the width of its own contents in a row, not of the column —
        # and `shrink-0`, or the strip never overflows: flex items default to
        # shrinking, so the chips squash to fit and the scroller has nothing to
        # scroll. Measured, not assumed; the first version had `w-auto` alone and
        # `scrollWidth === clientWidth`.
        STRIP_CHIP_TOKENS =
          "rows:[&_[data-slot=event-calendar-day-assignee]]:w-auto " \
          "rows:[&_[data-slot=event-calendar-day-assignee]]:shrink-0 " \
          "rows:[&_[data-slot=event-calendar-day-item]]:w-auto " \
          "rows:[&_[data-slot=event-calendar-day-item]]:shrink-0 " \
          "rows:[&_[data-slot=event-calendar-day-rest]]:w-auto " \
          "rows:[&_[data-slot=event-calendar-day-rest]]:shrink-0"
        # `contents` in the grid, so the number sits in the cell exactly as it did
        # before this existed; a real box only in rows, where it is the fixed
        # left-hand column. The other three utilities are inert under `contents`.


        # One chip per operator, the width of the cell, stacked. Full width rather
        # than an inline row of faces because the tally has to line up down the
        # column — that is what makes two days comparable at a glance, and a
        # wrapped row of avatar-and-number pairs never lines up with anything.
        # One class for both columns, and no `hidden` rule on either: a cell
        # renders the grouping it is showing and not the other one. Rendering both
        # and hiding one made switching free and everything else twice as
        # expensive — the same bargain `show_all:` stopped making, and the last
        # one left in this reading.
        CHIPS_CLASS = "flex w-full flex-col gap-0.5"

        # `bg-muted`, not a translucent `bg-background`. The translucent version
        # worked only while the cell underneath was tinted — the moment the ramp
        # moved to the count chip and the cell went plain, every chip was white on
        # white with a hairline round it. A chip needs a surface of its own, not a
        # borrowed one.
        ASSIGNEE_CLASS = "flex w-full items-center gap-1 overflow-hidden rounded-md " \
                                  "border border-border/40 bg-muted px-1 py-0.5 text-foreground"

        ASSIGNEE_AVATAR_CLASS = "size-4 shrink-0"
        # `bg-background` rather than the fallback's own `bg-muted`: the chip *is*
        # `bg-muted` now, so an avatar wearing it would be an invisible circle
        # with initials floating in it. Inverting them also lifts the initials off
        # the pair `accessibility_spec` excludes as upstream's — 4.34:1 on muted,
        # 4.74:1 on background.

        # No `sm:` gate on either of these any more. They were hidden on a phone
        # because a 46px grid cell could not hold a name — and below `lg` there is
        # no grid now, there is a row three hundred pixels wide. A breakpoint rule
        # written for a layout that no longer exists at any width is a rule that
        # only ever hides things.
        NAME_CLASS = "min-w-0 flex-1 truncate text-[0.65rem]"
        # An intervention chip is two levels: the clock and who is on it above,
        # what it is below. It is the one chip with room to be a card — an
        # operator chip is a face and a number and has nothing to put on a second
        # line.
        # The same tinted pair the bars wear, rather than a fixed `bg-muted`: an
        # intervention has a category and an operator does not, so this is the one
        # workload chip that carries `data-color`. Uncoloured, `--event-color` is
        # `--muted-foreground` and twelve per cent of it over the page is within a
        # hair of `bg-muted` — so a calendar that names no colours looks exactly
        # as it did before this could carry one.

        # An intervention chip is two levels: the clock and who is on it above,
        # what it is below. It is the one chip with room to be a card — an
        # operator chip is a face and a number and has nothing to put on a second
        # line.
        # The same tinted pair the bars wear, rather than a fixed `bg-muted`: an
        # intervention has a category and an operator does not, so this is the one
        # workload chip that carries `data-color`. Uncoloured, `--event-color` is
        # `--muted-foreground` and twelve per cent of it over the page is within a
        # hair of `bg-muted` — so a calendar that names no colours looks exactly
        # as it did before this could carry one.
        ITEM_CLASS = "flex w-full flex-col gap-1.5 overflow-hidden rounded-md " \
                             "border border-border/40 bg-[var(--event-color)]/12 px-1.5 py-1 " \
                             "text-(--event-ink)"


        # Text tokens, never the ramp's colour: the tint says how much, the
        # numerals stay ink.
        TALLY_CLASS = "ml-auto shrink-0 text-[0.65rem] font-medium tabular-nums"
        # The same chip, so the column keeps its rhythm rather than ending in a
        # different shape.
        # Only there when the cap is on: uncapped, the chips it was counting are
        # all on the page and a "+22" under them would be counting nothing.
        # `text-foreground`, not muted: the chip's surface became `bg-muted` when
        # the cell stopped being tinted, and muted-on-muted is 4.34:1 — the same
        # pair the avatar fallback was already excluded for — sixteen hundredths
        # under, there.
        # Rendered only when there is a remainder, which `show_all:` removes.

        # The same chip, so the column keeps its rhythm rather than ending in a
        # different shape.
        # Only there when the cap is on: uncapped, the chips it was counting are
        # all on the page and a "+22" under them would be counting nothing.
        # `text-foreground`, not muted: the chip's surface became `bg-muted` when
        # the cell stopped being tinted, and muted-on-muted is 4.34:1 — the same
        # pair the avatar fallback was already excluded for — sixteen hundredths
        # under, there.
        # Rendered only when there is a remainder, which `show_all:` removes.
        REST_CLASS = "justify-center text-[0.65rem] font-medium"

        # Above a dozen on the busiest day, a cell stops naming its events at any
        # width and shows the strip instead — the rule being that **a cell either
        # names its events or shows their shape, never half of each**.
        #
        # Twelve is where "+N" stops carrying its weight. Three bars and "+9" is
        # still a sentence: here are the next three, there are a few more. Three
        # bars and "+79" is not — the three are an arbitrary sample, the number is
        # the only information on the cell, and the events it is counting are
        # invisible until you open the day. The marks say all eighty-two.

        # A toggle, and a link when the caller can name the URL of the other
        # state — the shape `#nav_button` has for the months, and for the same
        # reason: what it changes is what the *server* renders, now that the cap
        # is applied there rather than by a class.
        #
        # It was a `Switch` while it was a class toggle. A switch hardcodes its
        # own `type="button"` and its own controller, so it cannot become a link
        # without fighting both, and a control whose job is to change server state
        # should be the thing that can.
        # Rows at a width that would otherwise get the grid.
        #
        # `max-lg:hidden` rather than a condition in Ruby: below `lg` the rows
        # are already what is drawn, so the button has nothing to change, and the
        # server cannot know which side of the breakpoint it is rendering for.
        # Hiding it in CSS is the only place that knows.
        #
        # `aria-pressed` and not a second radio menu: two states, one of which is
        # "leave it alone", is what a toggle is for. The grouping next to it is a
        # menu because a third cut is the obvious next question; a third
        # *arrangement* is not — see `ARRANGEMENTS`.

        # SPIKE — the hour axis on or off. Named for what it shows rather than
        # for the shape it makes, the way `Show all` is: a person reading the
        # toolbar is choosing between crews and clock, not between two layouts.

        def show_all_toggle
          nav_button(nil, size: :sm, action: "click->shadcn--event-calendar#showAll",
                     href: show_all_url&.call(!show_all),
                     pressed: show_all) do
            shadcn_t("event_calendar.group.show_all")
          end
        end

        def grouping_items
          safe_join([
            render(DropdownMenu::Label::Component.new) { shadcn_t("event_calendar.group.label") },
            render(DropdownMenu::Separator::Component.new),
            render(DropdownMenu::RadioGroup::Component.new) do
              safe_join(GROUPINGS.map { |name| grouping_item(name) })
            end
          ])
        end

        # Only the extra action goes here: the radio item already carries the
        # dropdown's own, and `data-action` is concatenated rather than replaced.

        # Only the extra action goes here: the radio item already carries the
        # dropdown's own, and `data-action` is concatenated rather than replaced.
        def grouping_item(name)
          href = group_url&.call(name)

          render(DropdownMenu::RadioItem::Component.new(
            value: name, checked: name == group,
            **(href ? { as: :a, href: } : { "data-action": "click->shadcn--event-calendar#regroup" })
          )) { shadcn_t("event_calendar.group.#{name}") }
        end

        def cell_body(day, on_day:, assignees:, hidden:)
          [
            tag.span(safe_join([ day_marker(day), count_chip(on_day.size) ].compact),
                     "data-slot": "event-calendar-day-head", class: HEAD_CLASS),
            if group == :assignees then assignee_chips(assignees)
            else item_chips(on_day, day)
            end
          ].compact
        end

        # Three faces and a "+2", busiest first. Identity is the initials or the
        # picture, never the colour — every avatar here is the same neutral, which
        # is what stops a fourth operator from needing a fourth hue.
        def assignee_chips(tallies)
          return if tallies.empty?

          shown = show_all ? tallies : tallies.first(CAP)

          tag.span(
            safe_join(shown.map { |assignee, count| assignee_chip(assignee, count) } +
                      [ rest_chip(tallies.size) ].compact),
            "data-slot": "event-calendar-day-assignees", class: CHIPS_CLASS
          )
        end

        def assignee_chip(assignee, count)
          tag.span(
            safe_join([
              render(Avatar::Component.new(size: :sm, class: ASSIGNEE_AVATAR_CLASS)) do |avatar|
                avatar.with_fallback(class: INITIALS_CLASS) { assignee.initials }
                avatar.with_image(src: assignee.image, alt: "") if assignee.image
              end,
              tag.span(assignee.name, class: NAME_CLASS),
              tag.span(count, class: TALLY_CLASS)
            ]),
            "data-slot": "event-calendar-day-assignee", class: ASSIGNEE_CLASS,
            title: "#{assignee.name}: #{count}"
          )
        end

        # One chip per intervention, in the order the day happens: the clock, who
        # it is for, and how many people it takes.

        # One chip per intervention, in the order the day happens: the clock, who
        # it is for, and how many people it takes.
        # A cell is its crossing jobs on the lanes they hold all week, then
        # everything else in the order `#day_sort_key` puts it.
        #
        # The lanes are what makes a five-day job read as one band across five
        # cells instead of five chips that happen to share a title: it keeps its
        # line even on a day when the line above it is empty, which is what the
        # `nil`s are for. Ordering alone could not do it — a second crossing job
        # starting halfway through the first moves the first one the day the
        # second ends.
        def item_chips(items, day)
          return if items.empty?

          rows = cell_rows(items, day)
          shown = show_all ? rows : rows.first(CAP)

          tag.span(
            safe_join(shown.map { |item| item ? item_chip(item, day) : held_lane } +
                      [ rest_chip(items.size) ].compact),
            "data-slot": "event-calendar-day-items", class: CHIPS_CLASS
          )
        end

        def cell_rows(items, day)
          crossing = schedule.crossing_on(day)

          crossing + (items - crossing.compact)
        end

        # A lane this day does not use, kept open so the day that does use it
        # finds it in the same place. Invisible rather than absent, and shaped
        # like a chip rather than given a height, so it cannot drift from one.
        def held_lane
          tag.span(
            safe_join([ tag.span("\u00A0", class: TIME_CLASS), tag.span("\u00A0", class: CHIP_TEXT_CLASS) ]),
            "data-slot": "event-calendar-day-held", class: [ ITEM_CLASS, "invisible" ],
            "aria-hidden": "true"
          )
        end

        def item_chip(item, day)
          tag.span(
            safe_join([ chip_head(item, day), chip_text(item) ]),
            "data-slot": "event-calendar-day-item", class: [ ITEM_CLASS, CROSSING_CLASS ],
            "data-color": item.color,
            **crossing_attributes(item, day),
            title: "#{item.title} — #{item.assignees.map(&:name).join(', ')}"
          )
        end

        def rest_chip(total)
          hidden = show_all ? 0 : total - CAP
          return if hidden <= 0

          tag.span("+#{hidden}", "data-slot": "event-calendar-day-rest",
                   class: "#{ASSIGNEE_CLASS} #{REST_CLASS}")
        end


        # The number, and — in the rows layout only — the weekday beside it. A
        # column heading cannot serve a row, so each row carries its own.
      end
    end
  end
end
