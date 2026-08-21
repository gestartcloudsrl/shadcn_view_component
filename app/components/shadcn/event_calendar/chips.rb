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
      # Smaller everywhere a month is not on a desktop. Two initials at 14px
      # still read; the circle is what gives way, not the type.
      # A face in a crew stack, which is not the same face as the one on an
      # assignee chip: these two shared a name after a rename and Ruby kept the
      # second, so the chip's avatar silently lost its `shrink-0` and shrank in
      # a scrolling row. `ruby -w` was the only thing that saw it — no spec did,
      # and rubocop has no cop for a reassigned constant.
      STACK_AVATAR_CLASS = "size-3.5 lg:size-4"

      CELL_CLASS = "gap-1 px-1 pt-1 pb-1"

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

      # `bg-background` rather than the fallback's own `bg-muted`: the chip *is*
      # `bg-muted` now, so an avatar wearing it would be an invisible circle
      # with initials floating in it. Inverting them also lifts the initials off
      # the pair `accessibility_spec` excludes as upstream's — 4.34:1 on muted,
      # 4.74:1 on background.
      INITIALS_CLASS = "bg-background text-[0.5rem] font-medium"
      # No `sm:` gate on either of these any more. They were hidden on a phone
      # because a 46px grid cell could not hold a name — and below `lg` there is
      # no grid now, there is a row three hundred pixels wide. A breakpoint rule
      # written for a layout that no longer exists at any width is a rule that
      # only ever hides things.

      CHIP_HEAD_CLASS = "flex items-center gap-1"

      CHIP_TEXT_CLASS = "truncate text-left text-[0.65rem] leading-tight"
      # Faces up to `AVATARS_CAP`, then a count.
      # `-space-x-1` overrides the group's own `-space-x-2`: upstream's overlap
      # is a quarter of a `size-8` avatar, and the same eight pixels on a
      # `size-4` one is half of it — the second initial disappears under the
      # next face. A quarter of *this* size is four.

      # Faces up to `AVATARS_CAP`, then a count.
      # `-space-x-1` overrides the group's own `-space-x-2`: upstream's overlap
      # is a quarter of a `size-8` avatar, and the same eight pixels on a
      # `size-4` one is half of it — the second initial disappears under the
      # next face. A quarter of *this* size is four.
      AVATARS_CLASS = "ml-auto flex shrink-0 -space-x-1"
      # Smaller everywhere a month is not on a desktop. Two initials at 14px
      # still read; the circle is what gives way, not the type.
      # A face in a crew stack, which is not the same face as the one on an
      # assignee chip: these two shared a name after a rename and Ruby kept the
      # second, so the chip's avatar silently lost its `shrink-0` and shrank in
      # a scrolling row. `ruby -w` was the only thing that saw it — no spec did,
      # and rubocop has no cop for a reassigned constant.

      AVATARS_MORE_CLASS = "size-3.5 bg-background text-[0.5rem] lg:size-4"
      # Three faces, then the fourth is the count. Five was the first guess and
      # it is too many at this size: the stack out-weighs the clock beside it,
      # and past three the faces stop being read individually anyway.

      # Three faces, then the fourth is the count. Five was the first guess and
      # it is too many at this size: the stack out-weighs the clock beside it,
      # and past three the faces stop being read individually anyway.
      AVATARS_CAP = 3
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
        return if count.zero?

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

      def chip_head(item)
        tag.span(
        safe_join([
          tag.span(chip_time(item) || shadcn_t("event_calendar.all_day"),
                   "data-slot": "event-calendar-day-time", class: TIME_CLASS),
          chip_avatars(item)
        ]),
        class: CHIP_HEAD_CLASS
        )
      end

      def chip_text(item)
        tag.span(item.title, "data-slot": "event-calendar-day-text",
               class: CHIP_TEXT_CLASS)
      end

      # `Avatar::Group` is upstream's own overlap and ring; the count past
      # `AVATARS_CAP` is its `GroupCount`, so the shape is shadcn's
      # rather than a lookalike.

      # `Avatar::Group` is upstream's own overlap and ring; the count past
      # `AVATARS_CAP` is its `GroupCount`, so the shape is shadcn's
      # rather than a lookalike.
      def chip_avatars(item)
        shown = item.assignees.first(AVATARS_CAP)
        rest = item.assignees.size - shown.size

        render(Avatar::Group::Component.new(class: AVATARS_CLASS)) do
        safe_join(shown.map { |assignee| avatar_for(assignee) } + [ avatars_more(rest) ].compact)
        end
      end

      def avatar_for(assignee)
        render(Avatar::Component.new(size: :sm, class: STACK_AVATAR_CLASS)) do |avatar|
        avatar.with_fallback(class: INITIALS_CLASS) { assignee.initials }
        avatar.with_image(src: assignee.image, alt: "") if assignee.image
        end
      end

      def avatars_more(count)
        return if count.zero?

        render(Avatar::GroupCount::Component.new(class: AVATARS_MORE_CLASS)
                                          .with_content("+#{count}"))
      end
    end
  end
end
