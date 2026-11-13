# frozen_string_literal: true

module Shadcn
  module EventCalendar
    # What one job looks like as a chip, and what a day's total looks like as a
    # badge — the two things the workload and hours readings genuinely share.
    #
    # They are here rather than on `EventCalendar::Component` because the events
    # reading draws neither: it draws bars and marks. And they are here rather
    # than on `Workload::Component` because hours draws both and is not a kind
    # of workload — it is a third reading that happens to want the same chip, so
    # that what the two differ in is the axis, not what an intervention looks
    # like.
    #
    # Included, so the constants resolve through the ancestor chain from either
    # component without qualification.
    module Chips
      include Faces

      # What a job that crosses days wears. Two things saying one thing, on
      # purpose — the same redundancy the events reading's bars have, where the
      # flat edge and the position both say "this continues".
      #
      # **The flat edge alone was not enough here.** It reads when chips sit in
      # a row — the strip below `lg`, the hours axis — because an edge that
      # runs off the end of something is a shape you can see. In a grid cell
      # they are stacked at full width, so a squared corner says nothing, and
      # two days of one job looked like two jobs.
      #
      # So the rail: a thread of the event's own colour down the left of any
      # chip that continues in either direction, which survives a stacked cell
      # and a narrow one. `data-[continues-after]` sets it too, so the first day
      # of a job is marked as much as its middle.
      # A rail on the edges where the chip was *cut*, so a day of a five-day job
      # says which day of it this is: the first has a rail on its right only,
      # the last on its left only, the ones between on both. The two rules for
      # `continues-after` used to name `border-l` as well, which made them
      # duplicates of the pair above and left the direction undrawn — every day
      # of a job rendered identically, with a left rail, including the day it
      # started on, which then read as continuing from a day before it.
      # Logical edges, not physical ones. `continues-before` and
      # `continues-after` are positions in *time*, and in a right-to-left locale
      # "before" is the right-hand end — `border-s`/`border-e` follow the reading
      # direction the browser has already resolved, `border-l`/`border-r` cannot.
      # These parts are the port's own, with no upstream class string to stay
      # identical to, so the choice is free here in a way it is not in the
      # families that are 1:1 — and upstream is physical almost everywhere.
      # `direction_spec` holds it: with `border-l` restored, its RTL example is
      # the one that fails. The hours axis still positions with `left`, which is
      # a separate job — see the todo.
      CROSSING_CLASS = "data-[continues-before]:rounded-s-none data-[continues-after]:rounded-e-none " \
                       "data-[continues-before]:border-s-2 data-[continues-before]:border-s-[var(--event-color)] " \
                       "data-[continues-after]:border-e-2 data-[continues-after]:border-e-[var(--event-color)]"
      # And what the rail cannot say: how long. `date_span` is how the agenda
      # has always said it, so the two agree.
      # No colour of its own: it inherits the chip's `--event-ink`, which is the
      # ink chosen to be readable on that chip's tint. `text-muted-foreground`
      # was grey on a green chip at 4.22 against a 4.5 threshold — a violation
      # that only surfaced once a fixture put a crossing job on a coloured chip.
      # And not the ink at `opacity-70` either, which reads as secondary and
      # measures 3.48: opacity buys the look by spending the contrast.
      SPAN_CLASS = "min-w-0 shrink truncate text-[0.65rem] tabular-nums"
      # The clock stops shrinking when the span is there to shrink instead.
      #
      # `TIME_CLASS` is shrinkable on purpose: below `sm` the title is hidden and
      # a fixed clock pushes the crew out of a 46px cell, because it is the only
      # flexible thing left. On a chip that carries a span it is not the only
      # one — and letting both shrink truncated the hour to "All …" and "9:00 …"
      # to make room for a date range, which is the wrong half to lose.
      TIME_FIXED_CLASS = "shrink-0"

      def crossing_attributes(item, day)
        { "data-continues-before": ("true" if item.start_date < day),
          "data-continues-after": ("true" if item.end_date > day) }
      end

      # ---- the workload reading -------------------------------------------
      #
      # A third way to read a cell, behind `reading: :workload`.
      #
      # The cell stops being a list and becomes a *measure*: a tint for how
      # much work the day holds, a count, and who did it.
      #
      # `CEILING` is where the ramp tops out — twenty-five and above
      # are the same colour, because a scale that keeps stretching to its worst
      # day flattens every other day into nothing.
      CEILING = 25
      # One hue, light to dark, which is the only correct shape for a
      # sequential scale — a green-amber-red "load" ramp is a rainbow wearing a
      # hard hat, and it makes 12 look like a different *kind* of day from 13
      # rather than a busier one. `--primary` so the ramp is the host's own
      # colour, and so dark mode gets its own direction rather than a flip:
      # `--primary` is near-black on a white surface and near-white on a dark
      # one, so "more" is always "more prominent".
      # The ramp runs almost its whole length rather than the fifth it started
      # at, and what bought the other four fifths is `INK_FLIPS_AT`:
      # a heat map capped at whatever keeps dark-on-light readable is a heat map
      # with no heat in it — 2 and 29 came out the same grey. Past the flip the
      # cell wears `--primary-foreground`, which is the ink that colour is *for*,
      # so both halves of the scale are legible and the whole of it is visible.
      #
      # 85 rather than 100 so the busiest day is still a cell rather than a
      # hole; 55 measured, not chosen — `--foreground` on a 60% tint is 4.4:1,
      # which AA does not take.
      # Two ways to cut the same day. Both are rendered and one is hidden, so
      # switching is a `data-group` on the root and no round trip — a spike can
      # afford the duplicate because both lists are capped at three chips.
      # Three ways of reading a month, and they are three different questions
      # about what a day *is*: a list of events, a quantity of work, or a
      # timeline. `:events` is the name; `:auto` is what it was called before
      # the other two existed and stays a synonym, because the gem is published
      # and a host's `reading: :auto` must keep working.

      TINT = 85

      INK_FLIPS_AT = 55

      HEAD_CLASS = "flex w-full items-center justify-between gap-1"
      # The one thing that wears the ramp. Its fill is the tint and nothing else
      # — no surface of its own — so a quiet day is an outline and a full one is
      # a solid pill, and the flip to `--primary-foreground` past the halfway
      # mark is the chip's own business rather than the whole cell's.
      COUNT_CLASS = "border-border/40 bg-transparent px-1.5 py-0 text-[0.65rem] " \
                           "tabular-nums text-foreground data-[heavy]:text-primary-foreground"
      # One chip per operator, the width of the cell, stacked. Full width rather
      # than an inline row of faces because the tally has to line up down the
      # column — that is what makes two days comparable at a glance, and a
      # wrapped row of avatar-and-number pairs never lines up with anything.
      # One class for both columns, and no `hidden` rule on either: a cell
      # renders the grouping it is showing and not the other one. Rendering both
      # and hiding one made switching free and everything else twice as
      # expensive — the same bargain `show_all:` stopped making, and the last
      # one left in this reading.

      TIME_CLASS = "min-w-0 truncate pe-2 text-[0.65rem] font-medium tabular-nums"
      # `bg-muted`, not a translucent `bg-background`. The translucent version
      # worked only while the cell underneath was tinted — the moment the ramp
      # moved to the count chip and the cell went plain, every chip was white on
      # white with a hairline round it. A chip needs a surface of its own, not a
      # borrowed one.

      # No `sm:` gate on either of these any more. They were hidden on a phone
      # because a 46px grid cell could not hold a name — and below `lg` there is
      # no grid now, there is a row three hundred pixels wide. A breakpoint rule
      # written for a layout that no longer exists at any width is a rule that
      # only ever hides things.

      # `min-h-6` is what a head with a crew measures — 24px, not the 16 of the
      # avatar's own `size-4`, which is what guessing it from the class got
      # wrong. Given to every head whether or not it has one, so a chip is a
      # chip: without it a reserved row came out 45px against a real 53, and
      # the band it was holding open sat at 81 pixels in some cells and 89 in
      # others.
      CHIP_HEAD_CLASS = "flex min-h-6 items-center gap-1"

      CHIP_TEXT_CLASS = "truncate text-left text-[0.65rem] leading-tight"
      # Text tokens, never the ramp's colour: the tint says how much, the
      # numerals stay ink.

      def share(count)
        [ count, CEILING ].min.fdiv(CEILING) * TINT
      end

      # The ramp crosses as a custom property rather than as a background, so
      # that *which element wears it* is a CSS decision. The grid paints the
      # cell; the rows layout paints only the count chip and leaves the row
      # plain. An inline background could not have been moved — a media query
      # cannot outrank a style attribute without `!important`.
      # One element wears the ramp, at every width: the count chip. Painting the
      # whole cell was the first design and it read as a *state* — selected,
      # disabled — where the same colour on the chip reads as the measure it is.
      #
      # Everything that existed only to survive a tinted cell went with it: the
      # ink flip on the cell, the ring that put today's circle back, and six CSS
      # rules that moved the tint between the two layouts. An inline
      # `background-image` is enough once nothing has to move it.
      def tint(count)
        "background-image:linear-gradient(#{ramp(count)},#{ramp(count)})"
      end

      def ramp(count)
        "color-mix(in oklab, var(--primary) #{share(count).round(2)}%, transparent)"
      end

      def count_chip(count)
        return if count.zero? || !counts

        render(Badge::Component.new(
        variant: :outline, class: COUNT_CLASS,
        "data-slot": "event-calendar-day-count",
        "data-heavy": ("true" if share(count) > INK_FLIPS_AT),
        style: tint(count)
        ).with_content(count.to_s))
      end

      # Three faces and a "+2", busiest first. Identity is the initials or the
      # picture, never the colour — every avatar here is the same neutral, which
      # is what stops a fourth operator from needing a fourth hue.

      # The clock for *this* day, not the job's first one. A chip is drawn on
      # every day a job covers, and it read "9:00 AM" on all of them — on the
      # third day of a three-day fit-out that is a time nothing happened at.
      # What a day wants to know is when the work is on it: the hour it starts
      # if it starts here, the hour it stops if it stops here, and the whole day
      # if it does neither.
      def chip_clock(item, day)
        return shadcn_t("event_calendar.all_day") if item.all_day_on?(day)
        return chip_time(item) if item.start_date == day
        return shadcn_t("event_calendar.all_day") unless item.ends_at.respond_to?(:hour)

        shadcn_t("event_calendar.until", time: I18n.l(item.ends_at, format: time_format))
      end

      def chip_head(item, day)
        tag.span(
        safe_join([
          tag.span(chip_clock(item, day),
                   "data-slot": "event-calendar-day-time",
                   class: [ TIME_CLASS, (TIME_FIXED_CLASS if item.multi_day?) ]),
          (if item.multi_day?
             tag.span(date_span(item), "data-slot": "event-calendar-day-span", class: SPAN_CLASS)
           end),
          flag_icons(item, "event-calendar-day"),
          chip_avatars(item)
        ].flatten.compact),
        class: CHIP_HEAD_CLASS
        )
      end

      # The title and the subtitle share one truncated line, so a long subtitle
      # gives way before the title does. The description is not on the chip at
      # all: it is a sentence, and a chip is a few words.
      # Joined with a real space: the chip is read from inside the day's target,
      # and "ServiceRossi" is what a screen reader makes of two adjacent nodes.
      def chip_text(item)
        tag.span(safe_join([ item.title, chip_subtitle(item) ].compact, " "),
                 "data-slot": "event-calendar-day-text",
                 class: CHIP_TEXT_CLASS)
      end

      def chip_subtitle(item)
        return if item.subtitle.blank?

        tag.span(item.subtitle, "data-slot": "event-calendar-day-subtitle", class: SUBTITLE_CLASS)
      end
    end
  end
end
