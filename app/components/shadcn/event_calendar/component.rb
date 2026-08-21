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

      # ---- the workload reading -------------------------------------------
      #
      # A third way to read a cell, behind `reading: :workload`.
      #
      # The cell stops being a list and becomes a *measure*: a tint for how
      # much work the day holds, a count, and who did it.
      #
      # `WORKLOAD_CEILING` is where the ramp tops out — twenty-five and above
      # are the same colour, because a scale that keeps stretching to its worst
      # day flattens every other day into nothing.
      WORKLOAD_CEILING = 25
      # One hue, light to dark, which is the only correct shape for a
      # sequential scale — a green-amber-red "load" ramp is a rainbow wearing a
      # hard hat, and it makes 12 look like a different *kind* of day from 13
      # rather than a busier one. `--primary` so the ramp is the host's own
      # colour, and so dark mode gets its own direction rather than a flip:
      # `--primary` is near-black on a white surface and near-white on a dark
      # one, so "more" is always "more prominent".
      # The ramp runs almost its whole length rather than the fifth it started
      # at, and what bought the other four fifths is `WORKLOAD_INK_FLIPS_AT`:
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
      READINGS = %i[auto workload].freeze

      # How the workload month is laid out. `:auto` is the breakpoint doing the
      # deciding — rows below `lg`, the seven-column grid above it — and
      # `:rows` is the toolbar overruling it. There is no `:grid`: forcing
      # seven columns onto a phone is the thing rows were built to avoid, so
      # the toggle only exists where it has something to change.
      ARRANGEMENTS = %i[auto rows].freeze
      # Past the last hue, for a colour the palette does not know.
      COLORS_END = Event::COLORS.size
      WORKLOAD_GROUPINGS = %i[assignees events].freeze
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
      WORKLOAD_CAP = 3

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
      ROWS_TOKENS =
        "rows:[&_[data-slot=event-calendar-week]]:contents " \
        "rows:[&_[data-slot=event-calendar-days]]:contents " \
        "rows:[&_[data-slot=event-calendar-weekdays]]:hidden " \
        "rows:[&_[data-slot=event-calendar-day]]:flex-row " \
        "rows:[&_[data-slot=event-calendar-day]]:items-center " \
        "rows:[&_[data-slot=event-calendar-day]]:gap-2 " \
        "rows:[&_[data-slot=event-calendar-day]]:px-2 " \
        "rows:[&_[data-slot=event-calendar-day]]:py-2 " \
        "rows:[&_[data-slot=event-calendar-day]]:h-20 " \
        "rows:[&_[data-slot=event-calendar-day]]:min-h-0 " \
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
        "rows:[&_[data-slot=event-calendar-day-items]]:min-w-0 " \
        "rows:[&_[data-slot=event-calendar-day-ticks]]:block " \
        "rows:[&_[data-slot=event-calendar-segments]]:hidden " \
        "rows:[&_[data-slot=event-calendar-day-item]_[data-slot=avatar-group]]:flex"
      # A chip is the width of its own contents in a row, not of the column —
      # and `shrink-0`, or the strip never overflows: flex items default to
      # shrinking, so the chips squash to fit and the scroller has nothing to
      # scroll. Measured, not assumed; the first version had `w-auto` alone and
      # `scrollWidth === clientWidth`.
      ROWS_CHIP_TOKENS =
        "rows:[&_[data-slot=event-calendar-day-assignee]]:w-auto " \
        "rows:[&_[data-slot=event-calendar-day-assignee]]:shrink-0 " \
        "rows:[&_[data-slot=event-calendar-day-item]]:w-auto " \
        "rows:[&_[data-slot=event-calendar-day-item]]:shrink-0 " \
        "rows:[&_[data-slot=event-calendar-day-rest]]:w-auto " \
        "rows:[&_[data-slot=event-calendar-day-rest]]:shrink-0"
      # `contents` in the grid, so the number sits in the cell exactly as it did
      # before this existed; a real box only in rows, where it is the fixed
      # left-hand column. The other three utilities are inert under `contents`.
      ROWS_LABEL_CLASS = "contents shrink-0 items-center gap-1"
      ROWS_WEEKDAY_CLASS = "hidden text-[0.7rem] font-normal text-muted-foreground tabular-nums"

      WORKLOAD_TINT = 85
      WORKLOAD_INK_FLIPS_AT = 55
      WORKLOAD_CELL_CLASS = "gap-1 px-1 pt-1 pb-1"
      WORKLOAD_HEAD_CLASS = "flex w-full items-center justify-between gap-1"
      # The one thing that wears the ramp. Its fill is the tint and nothing else
      # — no surface of its own — so a quiet day is an outline and a full one is
      # a solid pill, and the flip to `--primary-foreground` past the halfway
      # mark is the chip's own business rather than the whole cell's.
      WORKLOAD_COUNT_CLASS = "border-border/40 bg-transparent px-1.5 py-0 text-[0.65rem] " \
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
      WORKLOAD_CHIPS_CLASS = "flex w-full flex-col gap-0.5"

      # SPIKE — the hour track.
      #
      # It *fits* rather than scrolls, and that is the whole constraint. Each
      # row owns its own `overflow-x-auto` today, so two rows scrolled to
      # different offsets would put the same hour at two different x — which is
      # exactly the alignment the track exists to provide. A track that fits
      # cannot be scrolled out of agreement.
      #
      # Fitting costs the labels: 24 hours across ~1200px is 50px an hour, so
      # an hour-long appointment is a 50px bar. That is the labelled/dense
      # trade this component already makes for cells, arriving again on the
      # time axis — and the reason a bar carries its text in `title=`.
      TRACK_CLASS = "relative min-w-0 grow self-stretch"
      # Eight gridlines, matching the eight ruler marks `#track_hour_marks`
      # draws, whatever window the track is showing.
      TRACK_GRID_CLASS = "bg-[repeating-linear-gradient(to_right,var(--border)_0_1px,transparent_1px_12.5%)]"
      TRACK_HEIGHT_CLASS = "h-[calc((var(--lanes)*var(--lane-h))+0.35rem)]"
      TRACK_BAR_CLASS = "absolute top-(--lane) left-(--at) h-2 w-(--for) min-w-[3px] rounded-full"
      # A chip is placed by its start and sized by its content, so `--for` is
      # not used here at all: the duration stops being a length and goes back to
      # being the text in the clock. `max-w` is what stops a late-evening chip
      # running off the end of the track.
      TRACK_CHIP_CLASS = "absolute top-(--lane) left-(--at) flex w-auto max-w-[13rem] flex-col gap-1 " \
                         "overflow-hidden rounded-md border border-border/40 " \
                         "bg-[var(--event-color)]/12 px-1.5 py-1 text-(--event-ink)"
      # A share of the window, not a number of minutes — which is the bug the
      # first version had. The packer speaks minutes, but what decides whether
      # two chips collide is *pixels*, and how many pixels a minute is worth
      # depends on how many hours the track is showing. 120 minutes was a tenth
      # of a 07–23 window and a twelfth of a 00–24 one, so the same floor that
      # kept them apart on the short window let them pile up on the long one.
      #
      # Measured: a chip runs 93–160px on a ~1370px track, so the widest is
      # under 12% of it.
      TRACK_CHIP_SHARE = 0.12
      # Measured, not chosen: a chip renders 51px tall — a clock line, a gap and
      # a title — so a 2.9rem lane overlapped the next one by five pixels and
      # the bottom row of every busy day was clipped by the track's own height.
      TRACK_LANE_HEIGHTS = { bars: 0.9, chips: 3.4 }.freeze
      TRACK_BAR_PAINT_CLASS = "bg-[var(--event-color)]/70 ring-1 ring-background"
      # The ruler, drawn once above the month rather than once per row: it is
      # the same 24 hours on every row, and 42 copies of it would be 42 chances
      # to disagree.
      TRACK_RULER_CLASS = "flex items-end gap-0 pb-1 text-[0.6rem] text-muted-foreground"
      TRACK_RULER_PAD_CLASS = "w-14 shrink-0"
      TRACK_RULER_BODY_CLASS = "relative h-4 grow"
      TRACK_HOUR_CLASS = "absolute bottom-0 left-(--at) border-l border-border/60 pl-0.5"
      # Lanes aside, a track row is as tall as its lanes make it, so the fixed
      # `h-20` a rows-mode cell carries has to give way.
      # Only what the track *adds*. Everything else — weeks and days to
      # `contents`, the weekday strip and the outside days hidden, the cell laid
      # out as a row — is the rows arrangement, which a track always is.
      #
      # The scrolling half is the answer to a phone. Twenty-four hours across
      # 350px puts a 120px chip at a third of the track, so no packing floor
      # expressed as a share of the *window* can keep them apart — the chip's
      # width is in pixels and the window's is not. So the hour gets a fixed
      # width below `lg` and the month scrolls.
      #
      # One scroller for the whole month, not one per row: rows that scroll
      # independently sit at different offsets, and then the same x is a
      # different hour on each of them, which is the entire thing the track is
      # for. `overflow-x-auto` therefore goes on the frame, and the date column
      # is `sticky` so that scrolling the hours away does not take the day with
      # them.
      #
      # `self-stretch` on that column is not tidiness. Left to its content it
      # was 56×62 inside a 239px row, so a hundred and seventy-seven pixels of
      # it were not covering anything and chips on the lower lanes scrolled out
      # from under a box that stopped short. A frozen column has to be as tall
      # as the row it freezes. The border is what makes it read as a column
      # rather than as a cell that happens to stay put; the fill stays the
      # cell's own, so the only thing that changed is the shape.
      #
      # It does not follow the row's hover. A tint is translucent, and a frozen
      # column has to be opaque or the chips scrolling behind it show through —
      # which is the whole reason it is there.
      TRACK_TOKENS =
        "data-[track]:[--event-calendar-hour:0px] " \
        "max-lg:data-[track]:[--event-calendar-hour:22vw] " \
        "data-[track]:[&_[data-slot=event-calendar-grid]]:overflow-x-auto " \
        "data-[track]:[&_[data-slot=event-calendar-weeks]]:min-w-(--event-calendar-track) " \
        "data-[track]:[&_[data-slot=event-calendar-ruler]]:min-w-(--event-calendar-track) " \
        "data-[track]:[&_[data-slot=event-calendar-day]]:h-auto " \
        "data-[track]:[&_[data-slot=event-calendar-day]]:min-h-14 " \
        "data-[track]:[&_[data-slot=event-calendar-day]]:items-start " \
        "data-[track]:[&_[data-slot=event-calendar-day-head]]:sticky " \
        "data-[track]:[&_[data-slot=event-calendar-day-head]]:left-0 " \
        "data-[track]:[&_[data-slot=event-calendar-day-head]]:z-10 " \
        "data-[track]:[&_[data-slot=event-calendar-day-head]]:self-stretch " \
        "data-[track]:[&_[data-slot=event-calendar-day-head]]:justify-start " \
        "data-[track]:[&_[data-slot=event-calendar-day-head]]:pt-1.5 " \
        "data-[track]:[&_[data-slot=event-calendar-day-head]]:border-r " \
        "data-[track]:[&_[data-slot=event-calendar-day-head]]:bg-background " \
        "data-[track]:[&_[data-slot=event-calendar-ruler-pad]]:sticky " \
        "data-[track]:[&_[data-slot=event-calendar-ruler-pad]]:left-0 " \
        "data-[track]:[&_[data-slot=event-calendar-ruler-pad]]:z-10 " \
        "data-[track]:[&_[data-slot=event-calendar-ruler-pad]]:self-stretch " \
        "data-[track]:[&_[data-slot=event-calendar-ruler-pad]]:border-r " \
        "data-[track]:[&_[data-slot=event-calendar-ruler-pad]]:bg-background"
      # Shrinkable, not fixed: with the title hidden below `sm` there is
      # no flexible element left in the chip, and a `shrink-0` clock pushes the
      # crew size out of a 46px cell entirely. The clock truncating is a worse
      # look and a better chip — the number is the half that cannot be guessed.
      # `pe-2` rather than a wider gap on the head: the avatars are pushed right
      # by `ml-auto`, so the only thing guaranteeing a space when the clock runs
      # long is the clock's own padding — and it survives truncation, where the
      # ellipsis lands before the padding rather than against a face.
      WORKLOAD_TIME_CLASS = "min-w-0 truncate pe-2 text-[0.65rem] font-medium tabular-nums"
      # `bg-muted`, not a translucent `bg-background`. The translucent version
      # worked only while the cell underneath was tinted — the moment the ramp
      # moved to the count chip and the cell went plain, every chip was white on
      # white with a hairline round it. A chip needs a surface of its own, not a
      # borrowed one.
      WORKLOAD_ASSIGNEE_CLASS = "flex w-full items-center gap-1 overflow-hidden rounded-md " \
                                "border border-border/40 bg-muted px-1 py-0.5 text-foreground"
      WORKLOAD_ASSIGNEE_AVATAR_CLASS = "size-4 shrink-0"
      # `bg-background` rather than the fallback's own `bg-muted`: the chip *is*
      # `bg-muted` now, so an avatar wearing it would be an invisible circle
      # with initials floating in it. Inverting them also lifts the initials off
      # the pair `accessibility_spec` excludes as upstream's — 4.34:1 on muted,
      # 4.74:1 on background.
      WORKLOAD_INITIALS_CLASS = "bg-background text-[0.5rem] font-medium"
      # No `sm:` gate on either of these any more. They were hidden on a phone
      # because a 46px grid cell could not hold a name — and below `lg` there is
      # no grid now, there is a row three hundred pixels wide. A breakpoint rule
      # written for a layout that no longer exists at any width is a rule that
      # only ever hides things.
      WORKLOAD_NAME_CLASS = "min-w-0 flex-1 truncate text-[0.65rem]"
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
      WORKLOAD_ITEM_CLASS = "flex w-full flex-col gap-1.5 overflow-hidden rounded-md " \
                           "border border-border/40 bg-[var(--event-color)]/12 px-1.5 py-1 " \
                           "text-(--event-ink)"
      WORKLOAD_ITEM_HEAD_CLASS = "flex items-center gap-1"
      WORKLOAD_ITEM_TEXT_CLASS = "truncate text-left text-[0.65rem] leading-tight"
      # Faces up to `WORKLOAD_AVATARS_CAP`, then a count.
      # `-space-x-1` overrides the group's own `-space-x-2`: upstream's overlap
      # is a quarter of a `size-8` avatar, and the same eight pixels on a
      # `size-4` one is half of it — the second initial disappears under the
      # next face. A quarter of *this* size is four.
      WORKLOAD_AVATARS_CLASS = "ml-auto flex shrink-0 -space-x-1"
      # Smaller everywhere a month is not on a desktop. Two initials at 14px
      # still read; the circle is what gives way, not the type.
      # A face in a crew stack, which is not the same face as the one on an
      # assignee chip: these two shared a name after a rename and Ruby kept the
      # second, so the chip's avatar silently lost its `shrink-0` and shrank in
      # a scrolling row. `ruby -w` was the only thing that saw it — no spec did,
      # and rubocop has no cop for a reassigned constant.
      WORKLOAD_STACK_AVATAR_CLASS = "size-3.5 lg:size-4"
      WORKLOAD_AVATARS_MORE_CLASS = "size-3.5 bg-background text-[0.5rem] lg:size-4"
      # Three faces, then the fourth is the count. Five was the first guess and
      # it is too many at this size: the stack out-weighs the clock beside it,
      # and past three the faces stop being read individually anyway.
      WORKLOAD_AVATARS_CAP = 3
      # Text tokens, never the ramp's colour: the tint says how much, the
      # numerals stay ink.
      WORKLOAD_TALLY_CLASS = "ml-auto shrink-0 text-[0.65rem] font-medium tabular-nums"
      # The same chip, so the column keeps its rhythm rather than ending in a
      # different shape.
      # Only there when the cap is on: uncapped, the chips it was counting are
      # all on the page and a "+22" under them would be counting nothing.
      # `text-foreground`, not muted: the chip's surface became `bg-muted` when
      # the cell stopped being tinted, and muted-on-muted is 4.34:1 — the same
      # pair the avatar fallback was already excluded for — sixteen hundredths
      # under, there.
      # Rendered only when there is a remainder, which `show_all:` removes.
      WORKLOAD_REST_CLASS = "justify-center text-[0.65rem] font-medium"

      # Above a dozen on the busiest day, a cell stops naming its events at any
      # width and shows the strip instead — the rule being that **a cell either
      # names its events or shows their shape, never half of each**.
      #
      # Twelve is where "+N" stops carrying its weight. Three bars and "+9" is
      # still a sentence: here are the next three, there are a few more. Three
      # bars and "+79" is not — the three are an arbitrary sample, the number is
      # the only information on the cell, and the events it is counting are
      # invisible until you open the day. The marks say all eighty-two.
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

      style do
        base { "group/event-calendar w-full text-foreground #{COLOR_TOKENS} #{ROWS_TOKENS} #{ROWS_CHIP_TOKENS} #{TRACK_TOKENS}" }
      end

      attr_reader :month, :selected, :max_events, :schedule, :reading, :group, :month_url,
                  :day_url, :day_attributes, :agenda_as, :agenda_attributes,
                  :show_all, :show_all_url, :group_url, :arrangement, :arrangement_url, :track, :track_hours, :track_url, :track_as

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
                     week_starts_on: nil, reading: :auto, group: :assignees,
                     default_color: :default, month_url: nil, day_url: nil,
                     day_attributes: {}, agenda: true, agenda_as: :div, agenda_attributes: {},
                     show_all: false, show_all_url: nil, group_url: nil,
                     arrangement: :auto, arrangement_url: nil, track: false,
                     track_hours: (0..24), track_url: nil, track_as: :bars, **attributes)
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
        @show_all = show_all
        @show_all_url = show_all_url
        @group_url = group_url
        @agenda = agenda
        @agenda_as = agenda_as
        @agenda_attributes = agenda_attributes
        @reading = READINGS.include?(reading&.to_sym) ? reading.to_sym : :auto
        @group = WORKLOAD_GROUPINGS.include?(group&.to_sym) ? group.to_sym : :assignees
        @arrangement = ARRANGEMENTS.include?(arrangement&.to_sym) ? arrangement.to_sym : :auto
        @arrangement_url = arrangement_url
        @track = track
        @track_hours = track_hours
        @track_url = track_url
        @track_as = TRACK_LANE_HEIGHTS.key?(track_as&.to_sym) ? track_as.to_sym : :bars
        super(**attributes)
      end

      def element_attributes(**defaults)
        super(**{
          "data-controller" => "shadcn--event-calendar",
          "style" => merged_style("--event-calendar-cell:#{cell_height}rem",
                                  "--event-calendar-cell-more:#{cell_height(more: true)}rem",
                                  "--event-calendar-tick:#{tick_size}",
                                  ("--event-calendar-track:#{track_width}" if track?)),
          # Read by the `sm:group-data-[overflow]` rule on the cells, and reset
          # by the controller when it draws a month with a different answer.
          "data-overflow" => ("true" if labelled? && schedule.overflow?),
          # Whether this calendar names its events or shows their shape. See
          # `#labelled?` — it is the one decision that changes what a desktop
          # cell is made of.
          "data-labelled" => ("true" if labelled?),
          "data-group" => (group if workload?),
          "data-rows" => ("true" if workload?),
          # What the `rows:` variant reads at `lg` and above. `auto` is not the
          # absence of a value: the toggle flips between two named states, and
          # a controller that had to distinguish "unset" from "chosen" would be
          # reading the breakpoint it cannot see.
          # A track is a row per day and has no grid form, so it *is* the rows
          # arrangement rather than something laid over it. Said here, the
          # `rows:` variant does the whole layout and `TRACK_TOKENS` only has
          # to add what the track itself changes. Said anywhere else, pressing
          # the toggle took `data-arrangement` back to `auto`, the rows rules
          # stopped applying above `lg`, and what was left was a hybrid: weeks
          # still `contents`, cells no longer rows.
          "data-arrangement" => ((track? ? :rows : arrangement) if workload?),
          # SPIKE
          "data-track" => ("true" if track?),
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
        render_element(body: safe_join([ header, grid, (agenda if @agenda), prototypes ].compact))
      end

      private

      # Bars and a "+N" from `sm` up, or marks at every width. Decided per
      # calendar rather than per cell, because two cells in one grid made of
      # different things would read as two kinds of day.
      def labelled? = reading == :auto && schedule.busiest <= DENSE_ABOVE

      def workload? = reading == :workload

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
            (grouping_menu if workload?),
            # The track is always the rows arrangement, so `Rows` has nothing
            # to change there — but the slot must not go empty either, because
            # then there is no way out of the track. It gets its own toggle
            # instead, and the two are never both useful at once.
            (track? ? track_toggle : arrangement_toggle if workload?),
            # The way *into* the track, offered only to a caller that named its
            # URL — so the shipped readings gain no control they did not ask
            # for while the spike is being looked at.
            (track_toggle if workload? && !track? && track_url),
            (show_all_toggle if workload?),
            nav_button(Date.current, size: :sm, action: "click->shadcn--event-calendar#today") do
              shadcn_t("event_calendar.today")
            end,
            step_button(:previous),
            step_button(:next)
          ].compact),
          "data-slot": "event-calendar-nav", class: NAV_CLASS
        )
      end

      # Which way the cells are cut. A radio group rather than a toggle
      # because a third cut is the obvious next question, and a toggle would
      # have to become this anyway.
      def grouping_menu
        render(DropdownMenu::Component.new(align: :start)) do |dropdown|
          dropdown.with_trigger(class: Button::Component.variant_classes(variant: :outline, size: :sm)) do
            safe_join([
              tag.span(shadcn_t("event_calendar.group.#{group}"),
                       "data-shadcn--event-calendar-target": "groupLabel"),
              render(Icon::Component.new("chevron-down", class: CHEVRON_CLASS))
            ])
          end
          dropdown.with_menu_content(class: "w-52") { grouping_items }
        end
      end

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
      def arrangement_toggle
        wanted = arrangement == :rows ? :auto : :rows

        nav_button(nil, size: :sm, action: "click->shadcn--event-calendar#arrange",
                   href: arrangement_url&.call(wanted),
                   pressed: arrangement == :rows, classes: "max-lg:hidden",
                   value: wanted) do
          shadcn_t("event_calendar.arrangement.rows")
        end
      end

      # SPIKE — the hour axis on or off. Named for what it shows rather than
      # for the shape it makes, the way `Show all` is: a person reading the
      # toolbar is choosing between crews and clock, not between two layouts.
      def track_toggle
        nav_button(nil, size: :sm, action: "click->shadcn--event-calendar#retrack",
                   href: track_url&.call(!track?),
                   pressed: track?, value: (!track?).to_s) do
          shadcn_t("event_calendar.arrangement.hours")
        end
      end

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
            safe_join(WORKLOAD_GROUPINGS.map { |name| grouping_item(name) })
          end
        ])
      end

      # Only the extra action goes here: the radio item already carries the
      # dropdown's own, and `data-action` is concatenated rather than replaced.
      def grouping_item(name)
        href = group_url&.call(name)

        render(DropdownMenu::RadioItem::Component.new(
          value: name, checked: name == group,
          **(href ? { as: :a, href: } : { "data-action": "click->shadcn--event-calendar#regroup" })
        )) { shadcn_t("event_calendar.group.#{name}") }
      end

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
        tag.div(safe_join([ (track_ruler if track?), weekdays, weeks ].compact),
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
          safe_join(workload? ? workload_cell(day, on_day, assignees) : [ day_marker(day), ticks(on_day), more(hidden) ].compact),
          **(href ? { href: } : { type: "button", "data-action": "click->shadcn--event-calendar#select" }),
          **day_attributes,
          "data-slot": "event-calendar-day",
          class: [ DAY_CLASS, (WORKLOAD_CELL_CLASS if workload?) ].compact.join(" "),
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
      def workload_cell(day, on_day, assignees)
        [
          tag.span(safe_join([ day_marker(day), workload_count(on_day.size) ].compact),
                   "data-slot": "event-calendar-day-head", class: WORKLOAD_HEAD_CLASS),
          if track? then workload_track(day)
          elsif group == :assignees then workload_assignees(assignees)
          else workload_items(on_day)
          end
        ].compact
      end

      def track? = workload? && @track

      # SPIKE — a day as a 24-hour track.
      #
      # Position is a percentage of the day rather than a pixel, so the bars
      # stay aligned at every width without anything measuring anything: the
      # track is the same box on every row, and 09:15 is 38.5% of it whatever
      # that box happens to be.
      def workload_track(day)
        placed = schedule.track_on(day, floor: track_floor)
        lanes = placed.map { |_, lane, _, _| lane }.max.to_i + 1

        tag.span(safe_join(placed.map { |slot| track_chips? ? track_chip(*slot) : track_bar(*slot) }),
                 "data-slot": "event-calendar-day-track",
                 class: [ TRACK_CLASS, TRACK_GRID_CLASS, TRACK_HEIGHT_CLASS ],
                 style: "--lanes:#{lanes};--lane-h:#{TRACK_LANE_HEIGHTS.fetch(track_as)}rem")
      end

      def track_chips? = track_as == :chips

      def track_window_minutes = (track_hours.last - track_hours.first) * 60

      # `3.5rem` is the date column's own `w-14`, which does not scroll.
      def track_width
        "calc(3.5rem + (#{track_hours.last - track_hours.first} * var(--event-calendar-hour)))"
      end

      def track_floor
        return Schedule::TRACK_FLOOR unless track_chips?

        (track_window_minutes * TRACK_CHIP_SHARE).round
      end

      def track_chip(event, lane, from, _to)
        tag.span(
          safe_join([ workload_item_head(event), workload_item_text(event) ]),
          "data-slot": "event-calendar-day-item", class: TRACK_CHIP_CLASS,
          "data-color": event.color,
          style: "--at:#{track_at(from)};--lane:#{track_lane(lane)}",
          title: [ chip_time(event), event.title ].compact.join(" — ")
        )
      end

      def track_lane(lane) = "calc(#{lane} * var(--lane-h))"

      def track_bar(event, lane, from, to)
        tag.span(
          "", "data-slot": "event-calendar-day-bar",
          class: [ TRACK_BAR_CLASS, TRACK_BAR_PAINT_CLASS ],
          "data-color": event.color,
          style: "--at:#{track_at(from)};--for:#{track_span(to - from)};--lane:#{track_lane(lane)}",
          title: [ chip_time(event), event.title ].compact.join(" — ")
        )
      end

      # Minutes into a percentage of the *window*, not of the day. A calendar of
      # field work spent thirty per cent of its width on the hours between
      # midnight and seven, which is measured rather than guessed: the bars in
      # the 00–24 spike ran from 29.2% to 95.6% and nothing was ever drawn in
      # the first third.
      # Two of them, and the difference is the whole bug that made the first
      # windowed track a field of three-pixel ticks: a *position* is measured
      # from the start of the window and a *length* is not, so subtracting the
      # window offset from a duration turned every sixty-minute job negative
      # and left `min-w` to draw it.
      def track_at(minutes) = track_span(minutes - (track_hours.first * 60))

      def track_span(minutes)
        "#{((minutes / ((track_hours.last - track_hours.first) * 60.0)) * 100).round(3)}%"
      end

      def track_hour_marks
        step = ((track_hours.last - track_hours.first) / 8.0).ceil
        (track_hours.first...track_hours.last).step(step)
      end

      # The hours, once, above the month.
      def track_ruler
        tag.div(
          safe_join([
            tag.span("", "data-slot": "event-calendar-ruler-pad", class: TRACK_RULER_PAD_CLASS),
            tag.span(safe_join(track_hour_marks.map { |hour| track_hour(hour) }),
                     class: TRACK_RULER_BODY_CLASS)
          ]),
          "data-slot": "event-calendar-ruler", class: TRACK_RULER_CLASS, "aria-hidden": "true"
        )
      end

      def track_hour(hour)
        tag.span(format("%02d", hour), class: TRACK_HOUR_CLASS,
                 style: "--at:#{track_at(hour * 60)}")
      end

      def workload_share(count)
        [ count, WORKLOAD_CEILING ].min.fdiv(WORKLOAD_CEILING) * WORKLOAD_TINT
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
      def workload_tint(count)
        "background-image:linear-gradient(#{workload_ramp(count)},#{workload_ramp(count)})"
      end

      def workload_ramp(count)
        "color-mix(in oklab, var(--primary) #{workload_share(count).round(2)}%, transparent)"
      end

      def workload_count(count)
        return if count.zero?

        render(Badge::Component.new(
          variant: :outline, class: WORKLOAD_COUNT_CLASS,
          "data-slot": "event-calendar-day-count",
          "data-heavy": ("true" if workload_share(count) > WORKLOAD_INK_FLIPS_AT),
          style: workload_tint(count)
        ).with_content(count.to_s))
      end

      # Three faces and a "+2", busiest first. Identity is the initials or the
      # picture, never the colour — every avatar here is the same neutral, which
      # is what stops a fourth operator from needing a fourth hue.
      def workload_assignees(tallies)
        return if tallies.empty?

        shown = show_all ? tallies : tallies.first(WORKLOAD_CAP)

        tag.span(
          safe_join(shown.map { |assignee, count| workload_assignee(assignee, count) } +
                    [ workload_rest(tallies.size) ].compact),
          "data-slot": "event-calendar-day-assignees", class: WORKLOAD_CHIPS_CLASS
        )
      end

      def workload_assignee(assignee, count)
        tag.span(
          safe_join([
            render(Avatar::Component.new(size: :sm, class: WORKLOAD_ASSIGNEE_AVATAR_CLASS)) do |avatar|
              avatar.with_fallback(class: WORKLOAD_INITIALS_CLASS) { assignee.initials }
              avatar.with_image(src: assignee.image, alt: "") if assignee.image
            end,
            tag.span(assignee.name, class: WORKLOAD_NAME_CLASS),
            tag.span(count, class: WORKLOAD_TALLY_CLASS)
          ]),
          "data-slot": "event-calendar-day-assignee", class: WORKLOAD_ASSIGNEE_CLASS,
          title: "#{assignee.name}: #{count}"
        )
      end

      # One chip per intervention, in the order the day happens: the clock, who
      # it is for, and how many people it takes.
      def workload_items(items)
        return if items.empty?

        shown = show_all ? items : items.first(WORKLOAD_CAP)

        tag.span(
          safe_join(shown.map { |item| workload_item(item) } +
                    [ workload_rest(items.size) ].compact),
          "data-slot": "event-calendar-day-items", class: WORKLOAD_CHIPS_CLASS
        )
      end

      def workload_item(item)
        tag.span(
          safe_join([ workload_item_head(item), workload_item_text(item) ]),
          "data-slot": "event-calendar-day-item", class: WORKLOAD_ITEM_CLASS,
          "data-color": item.color,
          title: "#{item.title} — #{item.assignees.map(&:name).join(', ')}"
        )
      end

      def workload_item_head(item)
        tag.span(
          safe_join([
            tag.span(chip_time(item) || shadcn_t("event_calendar.all_day"),
                     "data-slot": "event-calendar-day-time", class: WORKLOAD_TIME_CLASS),
            workload_avatars(item)
          ]),
          class: WORKLOAD_ITEM_HEAD_CLASS
        )
      end

      def workload_item_text(item)
        tag.span(item.title, "data-slot": "event-calendar-day-text",
                 class: WORKLOAD_ITEM_TEXT_CLASS)
      end

      # `Avatar::Group` is upstream's own overlap and ring; the count past
      # `WORKLOAD_AVATARS_CAP` is its `GroupCount`, so the shape is shadcn's
      # rather than a lookalike.
      def workload_avatars(item)
        shown = item.assignees.first(WORKLOAD_AVATARS_CAP)
        rest = item.assignees.size - shown.size

        render(Avatar::Group::Component.new(class: WORKLOAD_AVATARS_CLASS)) do
          safe_join(shown.map { |assignee| avatar_for(assignee) } + [ avatars_more(rest) ].compact)
        end
      end

      def avatar_for(assignee)
        render(Avatar::Component.new(size: :sm, class: WORKLOAD_STACK_AVATAR_CLASS)) do |avatar|
          avatar.with_fallback(class: WORKLOAD_INITIALS_CLASS) { assignee.initials }
          avatar.with_image(src: assignee.image, alt: "") if assignee.image
        end
      end

      def avatars_more(count)
        return if count.zero?

        render(Avatar::GroupCount::Component.new(class: WORKLOAD_AVATARS_MORE_CLASS)
                                            .with_content("+#{count}"))
      end

      def workload_rest(total)
        hidden = show_all ? 0 : total - WORKLOAD_CAP
        return if hidden <= 0

        tag.span("+#{hidden}", "data-slot": "event-calendar-day-rest",
                 class: "#{WORKLOAD_ASSIGNEE_CLASS} #{WORKLOAD_REST_CLASS}")
      end


      # The number, and — in the rows layout only — the weekday beside it. A
      # column heading cannot serve a row, so each row carries its own.
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
