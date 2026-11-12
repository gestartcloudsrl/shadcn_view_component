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
      include Faces
      include PreferencesDialog

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

      # Every shape a timeline can draw a job in, in the order the panel offers
      # them; the first is the default. Here rather than in `Hours`, because the
      # question is asked from a month that is not a timeline: the panel on a
      # grid has to know whether *Monthly · Timeline* would have anything to
      # ask.
      SHAPES = %i[chips bars].freeze

      READINGS = %i[auto events workload hours daily weekly].freeze

      # How the workload month is laid out. `:auto` is the breakpoint doing the
      # deciding — rows below `lg`, the seven-column grid above it — and
      # `:rows` is the toolbar overruling it. There is no `:grid`: forcing
      # seven columns onto a phone is the thing rows were built to avoid, so
      # the toggle only exists where it has something to change.
      ARRANGEMENTS = %i[auto rows].freeze

      # The three views the options panel offers, which is one list because a
      # person picking one is answering one question. Two of them are the
      # workload reading at two arrangements and the third is a different
      # reading entirely — a distinction that matters to this file and to nobody
      # using it, which is why `view_url:` is one callback and not two.
      #
      # It is handed a *period* or a *view*, though, and it used to be handed
      # `:grid` for the monthly period — which reads as "monthly means grid" and
      # is the one thing it must not say. A host that keeps the two questions
      # apart, as the panel does, could not tell "show me the month again" from
      # "draw the month as a grid", so leaving the daily view sent you back to
      # grid however you had been reading the month. It now receives `:monthly`,
      # and the callback's vocabulary is `PERIODS + VIEWS` with nothing standing
      # in for anything else.
      VIEWS = %i[grid rows hours].freeze

      # The views a week offers: the same words, without the grid. Seven narrow
      # columns are what the rows were built to avoid, so a week has nothing to
      # put there.
      WEEK_VIEWS = %i[rows hours].freeze

      # The period the toolbar switches between, above the views. A month has
      # three ways of being read and a day has one; `PERIODS` is what the panel
      # asks first, and `VIEWS` is only the monthly follow-up.
      PERIODS = %i[monthly weekly daily].freeze

      # Keywords a *reading* owns. A reading that declares one consumes it and
      # it never arrives here; one that does not would forward it to the element
      # like any other prop, and `Component.new(reading: :auto, group: :events)`
      # rendered `group="events"` on the root — an attribute HTML has no idea
      # what to do with.
      #
      # So they are namespaced instead of passed through. The element says
      # `data-event-calendar-group="events"`, which is at least valid and at
      # least legible in an inspector; what it does *not* mean is that this
      # calendar groups by event, because a reading without a grouping has none
      # — it means someone asked for one here.
      #
      # Callables are dropped rather than stringified: a `#{group_url}` in the
      # markup is a `#<Proc>` and nothing else.
      READING_KEYWORDS = %i[group group_url show_all show_all_url arrangement
                            window shape shape_url showing showing_url].freeze
      # Past the last hue, for a colour the palette does not know.
      COLORS_END = Event::COLORS.size
      # The same ranking as `COLORS.index`, resolved once. It sits inside a
      # comparator, so the linear scan it replaces ran on every comparison.
      COLOR_RANK = Event::COLORS.each_with_index.to_h.freeze
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
        "rows:[&_[data-slot=event-calendar-day-head]]:gap-1 " \
        "rows:[&_[data-slot=event-calendar-day-label]]:flex " \
        "rows:[&_[data-slot=event-calendar-day-label]]:w-full " \
        "rows:[&_[data-slot=event-calendar-day-label]]:flex-col " \
        "rows:[&_[data-slot=event-calendar-day-label]]:items-center " \
        "rows:[&_[data-slot=event-calendar-day-label]]:gap-0 " \
        "rows:[&_[data-slot=event-calendar-day-weekday]]:block " \
        "rows:[&_[data-slot=event-calendar-day-number]]:text-sm " \
        "rows:[&_[data-slot=event-calendar-segments]]:hidden "
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
      # The header wraps the nav under the title, and that is not enough on a
      # phone: the nav was one unbreakable row, 406px of it for the day against
      # 342px of header at 390px wide, so the page scrolled sideways. It wraps
      # too, and `min-w-0` lets it be narrower than that row, so its controls
      # go onto a second line instead of past the edge. Nothing is clipped.
      # From 768px up every reading in the gallery fits its nav on one line
      # beside the title, so neither class changes anything there.
      #
      # `min-w-0` on the title for the same reason, in a title too long for the
      # line: it wraps instead of truncating, because `leading-none` with
      # `overflow-hidden` would clip the descenders of "agosto".
      TITLE_CLASS = "min-w-0 text-base leading-none font-semibold sm:text-lg"
      NAV_CLASS = "flex min-w-0 flex-wrap items-center gap-1"
      CHEVRON_CLASS = "size-4"
      # `overflow-clip`, not `overflow-hidden`: both cut the corners, but
      # `hidden` makes the frame a scroll container, and a `sticky` row inside
      # one sticks to the frame, which never scrolls, so it stayed put. `clip`
      # leaves the page as the scroller the weekday row sticks to.
      FRAME_CLASS = "overflow-clip rounded-md border"
      # The weekday row stays at the top while a tall month scrolls the page
      # under it. It stops at `--event-calendar-sticky-top`, 0 unless the host
      # sets it, so a host with a fixed navbar puts the row below that bar
      # rather than under it.
      #
      # The row is opaque and the tint is on each name, where the row used to be
      # `bg-muted/50` alone: half-transparent, the cells scrolling under it
      # showed through. The names fill the row with no gap.
      #
      # What the row is opaque *with* is whatever used to show through the
      # tint: the surface the calendar sits on. That is the page's
      # `--background`, or `--card` inside a Card (the `data-slot=card` rule,
      # as `calendar.tsx` keys its own background off `card-content`). A host
      # on any other surface names it in `--event-calendar-sticky-bg`. With
      # `--background` alone, a calendar in a dark-palette Card had a row
      # darker than before, because the tint went over 0.145 instead of 0.205.
      WEEKDAYS_CLASS = "sticky top-[var(--event-calendar-sticky-top,0px)] z-10 grid grid-cols-7 border-b " \
                       "bg-[color:var(--event-calendar-sticky-bg,var(--background))] " \
                       "[[data-slot=card]_&]:bg-[color:var(--event-calendar-sticky-bg,var(--card))]"
      WEEKDAY_CLASS = "bg-muted/50 py-2 text-center text-[0.7rem] font-medium text-muted-foreground " \
                      "select-none sm:text-xs"
      # `gap-px` over a `bg-border` parent, rather than a border on each cell:
      # borders double up where two cells meet and the grid ends up with lines
      # of two widths, which is the thing a month grid cannot have.
      WEEKS_CLASS = "flex flex-col gap-px bg-border"
      WEEK_CLASS = "relative"
      DAYS_CLASS = "grid grid-cols-7 gap-px"
      # The selected day wears an **outline**, not a second ring, and both halves
      # of that were measured rather than chosen.
      #
      # `bg-accent` alone separates a selected cell from a plain one by 0.030 of
      # perceptual lightness in the light palette — `oklch(0.97)` against
      # `oklch(1)` — where the dark palette gets 0.124. A quarter of the signal,
      # in the palette most people are looking at, which is why clicking a day
      # read as nothing happening at all.
      #
      # `ring-2` was tried first and collapsed two states into one: it and
      # `focus-visible:ring-[3px]` are the same property, so Tailwind's order
      # decides and selection won — a focused cell and a merely selected one
      # rendered identically. `outline` is a different property, so the two now
      # stack: focus keeps its 3px translucent ring, selection carries a 2px
      # solid one, and a cell that is both shows both.
      #
      # `--ring` rather than `--primary`, because the day *number* already wears
      # primary when it is today and two primaries on one cell say one thing
      # twice.
      #
      # **And neither state raises the cell.** Both used to carry `z-10`, to keep
      # their decoration off the neighbouring cells — and a cell is opaque
      # (`bg-background`) and sits under the absolutely positioned bar layer, so
      # raising it painted its own background over every bar crossing it: a
      # selected day, and the day a keyboard was standing on, showed no events at
      # all while the agenda underneath listed them.
      #
      # The `z-10` bought nothing either time. Both decorations are drawn
      # *inside* the cell's own box — `outline-offset: -2px` and `ring-inset` —
      # so no neighbour can clip them and nothing needs to be lifted over
      # anything. `topmost_over` in `system/event_calendar_spec.rb` holds it, by
      # hit-testing the middle of a bar rather than reading an attribute, which
      # is the only thing that can see a paint order.
      DAY_CLASS = "group/day relative flex min-h-14 w-full flex-col items-center gap-1 bg-background px-0.5 " \
                  "pt-1.5 pb-1 text-left outline-none transition-colors hover:bg-accent/50 " \
                  "focus-visible:ring-[3px] focus-visible:ring-ring/50 " \
                  "focus-visible:ring-inset data-[selected]:bg-accent " \
                  "data-[selected]:[outline:2px_solid_var(--ring)] " \
                  "data-[selected]:[outline-offset:-2px] " \
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
      # What a bar wears only when it can be moved, so a read-only calendar's
      # markup is the markup it always was.
      EVENT_MOVING_CLASS = "data-[picked]:ring-2 data-[picked]:ring-ring data-[pending]:opacity-50"
      # The grip, and only the grip, takes the pointer: the layer around it stays
      # `pointer-events-none`, so the gaps between bars still belong to the day.
      # Making the whole bar grabbable took the centre of 17 of the 27 days that
      # had events — the measurement is in the design.
      EVENT_GRIP_CLASS = "pointer-events-auto -ml-0.5 h-full w-2 shrink-0 cursor-grab rounded-l-sm " \
                         "bg-(--event-color)/40 hover:bg-(--event-color)"
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
      # What the agenda wants that `Item`'s own `size: :sm` does not give it: its
      # rows are dense, and a row is two lines that have to reach the same
      # height, so the colour beside them can run their length.
      AGENDA_ITEM_CLASS = "items-stretch px-2 py-2"
      AGENDA_LINK_CLASS = "transition-colors hover:bg-accent focus-visible:outline-none " \
                          "focus-visible:ring-[3px] focus-visible:ring-ring/50"
      # The faces in a row are the chip's faces inverted back. `Faces` gives an
      # avatar `bg-background` because a chip is `bg-muted`, and a row sits on
      # the page's own `bg-background` — so there the circle vanished and only
      # the initials floated. A row takes upstream's `bg-muted` again, and
      # `bg-background` once it is itself `bg-accent`, hovered as a link or
      # picked to move: every theme here gives `--accent` and `--muted` the same
      # value, so `bg-muted` alone would vanish a second time. Written on the
      # wrapper rather than on the face because the browser clones one face for
      # chip and row alike.
      AGENDA_AVATARS_CLASS = "flex shrink-0 items-center " \
                             "[&_[data-slot=avatar-fallback]]:bg-muted " \
                             "[&_[data-slot=avatar-group-count]]:bg-muted " \
                             "[a:hover_&_[data-slot=avatar-fallback]]:bg-background " \
                             "[a:hover_&_[data-slot=avatar-group-count]]:bg-background " \
                             "[[data-picked]_&_[data-slot=avatar-fallback]]:bg-background " \
                             "[[data-picked]_&_[data-slot=avatar-group-count]]:bg-background"
      # The colour, and the reason the row is `items-stretch`: a dot marks a line
      # and a bar marks a row, and a row here is two lines. It keeps its slot
      # name because it keeps its job — a host styling the colour of an agenda
      # row still has the same thing to reach for.
      AGENDA_MARK_CLASS = "w-1.5 shrink-0 self-stretch rounded-full bg-(--event-color)"
      # The mark is the row's grip when the row can be moved — the colour and the
      # handle are the same bar, as they are on a chip.
      AGENDA_MARK_GRIP_CLASS = "cursor-grab"
      # A row a keyboard can reach, and can see it has taken hold of.
      AGENDA_PICK_CLASS = "rounded-md outline-none focus-visible:ring-[3px] focus-visible:ring-ring/50 " \
                          "data-[picked]:bg-accent data-[picked]:ring-2 data-[picked]:ring-ring"
      AGENDA_CONTENT_CLASS = "min-w-0 gap-0.5"
      AGENDA_EVENT_TITLE_CLASS = "truncate font-medium"
      # `Item::Description` is already `text-muted-foreground`; only the size is
      # the agenda's own.
      AGENDA_META_CLASS = "truncate text-xs"
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

      attr_reader :movable, :month, :selected, :max_events, :schedule, :reading, :month_url,
                  :day_url, :day_attributes, :agenda_as, :agenda_attributes,
                  :view_url, :shapes

      # The readings that are not this class. `.new` hands over to them, so a
      # host writes `Component.new(reading: :hours)` and never names a subclass
      # — the dispatcher is the constructor, not a wrapper element, so nothing
      # extra is rendered and the root stays one element.
      RENDERERS = {
        workload: "Shadcn::EventCalendar::Workload::Component",
        hours: "Shadcn::EventCalendar::Hours::Component",
        daily: "Shadcn::EventCalendar::Daily::Component",
        weekly: "Shadcn::EventCalendar::Weekly::Component"
      }.freeze

      # The week has two views and one reading name: `arrangement: :rows` is
      # what tells them apart, the keyword the month's rows already use.
      WEEKLY_ROWS = "Shadcn::EventCalendar::WeeklyRows::Component"

      def self.new(reading: :auto, **rest)
        renderer = RENDERERS[reading&.to_sym]
        # Built directly, `WeeklyRows` is already the week it would hand over
        # to — without this `reading: :weekly` would send it to the timeline.
        if renderer == RENDERERS[:weekly] && (name == WEEKLY_ROWS || rest[:arrangement]&.to_sym == :rows)
          renderer = WEEKLY_ROWS
        end

        return super(reading:, **rest) if renderer.nil? || name == renderer

        renderer.constantize.new(reading:, **rest)
      end

      # @param month [Date, nil] which month is shown; defaults to today's
      # @param selected [Date, nil] the day the agenda reads out; defaults to
      #   today when today is in view, and to the first of the month otherwise
      # @param events [Array<Hash, Event>] `{ title:, starts_at:, ends_at:,
      #   color:, url:, all_day:, subtitle:, description:, done:, attachment:,
      #   attributes: }` — `ends_at` is *inclusive*; `color:` is a palette name
      #   or the name of a custom property (`"--chart-2"`); `done:` and
      #   `attachment:` take `true` or `{ label: }`, the words a screen reader
      #   hears instead of the gem's; an assignee may carry a `status:` of
      #   `:done` or `:pending`, and a `label:` read out instead of the status's
      # @param max_events [Integer] bars per cell before a cell says "+2"
      # @param week_starts_on [Integer, nil] `Date#wday`; the host's
      #   `Date.beginning_of_week` when not given
      # @param day_url [#call, nil] given a `Date`, the URL of that day. Present,
      #   a cell is a link and the server owns what a click shows; absent, it is
      #   a button and the controller redraws the agenda in place.
      # @param day_attributes [Hash] merged onto every day cell — where a
      #   `data: { turbo_frame: … }` goes
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
      # @param shapes [Array<Symbol>] the shapes a host offers. One alone is
      #   that shape at every request, and the panel drops the question and
      #   the trigger stops naming it: a host whose people never want bars
      #   should not have them mentioned. Unknown names are ignored, and
      #   none left means every shape.
      # @param preferences [Symbol, nil] `:local` keeps a person's preferred view
      #   in their browser, `:host` sends the form to `preferences_save_url:`;
      #   absent, there is no preferences item at all. Readings without a panel
      #   (`:auto`) ignore it.
      # @param preferences_url [#call, nil] `:local` only: given a set of
      #   preferences, the URL of that view. Every set is shipped to the
      #   browser, so the callable runs once per set at render.
      # @param preferences_save_url [String, nil] `:host` only: where the form
      #   is `PATCH`ed
      # @param restore [Boolean] `:local` only: whether the browser sends a
      #   person to their saved view on arrival. Every URL the host hands the
      #   calendar (`month_url:`, `day_url:`, `view_url:`...) must carry whatever
      #   the host's restore test reads, or the next request looks like a bare
      #   arrival and pulls the person back to their saved view.
      def initialize(month: nil, selected: nil, events: nil, max_events: 3,
                     week_starts_on: nil, reading: :auto,
                     default_color: :default, month_url: nil, day_url: nil,
                     day_attributes: {}, agenda: true, agenda_as: :div, agenda_attributes: {},
                     view_url: nil, movable: false, shapes: SHAPES,
                     preferences: nil, preferences_url: nil, preferences_save_url: nil, restore: false,
                     **attributes)
        @month = Calendar::Month.new(month || Date.current, week_starts_on:)
        @max_events = max_events.to_i.clamp(MAX_EVENTS.first, MAX_EVENTS.last)
        @selected = (selected || default_selection).to_date
        @schedule = Schedule.new(month: @month, events:, max_lanes: @max_events, default_color:)
        @month_url = month_url
        @day_url = day_url
        @day_attributes = day_attributes
        @agenda = agenda
        @agenda_as = agenda_as
        @agenda_attributes = agenda_attributes
        # Checked against its list. Unchecked, `reading: :workLoad` off a params
        # hash fell through every branch and rendered a silent fourth thing: no
        # bars, no `data-labelled`, no rows.
        @reading = READINGS.include?(reading&.to_sym) ? reading.to_sym : :auto
        @reading = :auto if @reading == :events
        @view_url = view_url
        @shapes = SHAPES & Array(shapes).map { |name| name.to_s.to_sym }
        @shapes = SHAPES if @shapes.empty?
        @movable = !!movable
        require_identities! if @movable
        initialize_preferences(preferences, preferences_url, preferences_save_url, restore)
        super(**attributes)
      end

      def movable? = movable

      # A move dispatches the host's own id, and `Event#id` is `nil` unless the
      # host passed one — it has existed for `#portable_events` and nothing has
      # needed it since. Left alone this ships `id: null` inside a `CustomEvent`,
      # which fails as "dragging does nothing" days later and in somebody else's
      # code. So it is a render-time error, and it names the event rather than
      # counting them.
      def require_identities!
        nameless = schedule.events.find { |event| event.id.blank? }
        return unless nameless

        raise ArgumentError,
              "EventCalendar(movable: true) needs an id on every event; #{nameless.title.inspect} has none"
      end

      # Anything a reading owns that reached this far was meant for a different
      # one — see `READING_KEYWORDS`.
      def attributes
        super.to_h do |key, value|
          next [ key, value ] unless READING_KEYWORDS.include?(key)

          [ :"data-event-calendar-#{key.to_s.tr('_', '-')}", (value unless value.respond_to?(:call)) ]
        end.compact
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
          **preference_attributes,
          "data-shadcn--event-calendar-month-value" => month.first.iso8601,
          # The application's today, not the browser's — the same reason the
          # calendar crosses one: `Time.zone` and a laptop's clock disagree by a
          # day for a few hours out of every twenty-four.
          "data-shadcn--event-calendar-today-value" => today.iso8601,
          "data-shadcn--event-calendar-selected-value" => selected.iso8601,
          "data-shadcn--event-calendar-week-starts-on-value" => month.week_starts_on,
          "data-shadcn--event-calendar-max-events-value" => max_events,
          "data-shadcn--event-calendar-tick-sizes-value" => TICK_SIZES.to_json,
          "data-shadcn--event-calendar-dense-above-value" => DENSE_ABOVE,
          # The one constructor argument that did not cross, and both halves of
          # that were bugs: the controller re-derived `labelled` from density
          # alone, so one press of › stamped `data-labelled` on a workload
          # calendar and ran both readings at once.
          # Omitted rather than `"false"`, like `data-labelled` above: the
          # controller's own default is false, and every calendar in a host's
          # app that never moves anything would otherwise carry the byte.
          "data-shadcn--event-calendar-movable-value" => ("true" if movable?),
          "data-shadcn--event-calendar-reading-value" => reading,
          # Whether the browser may redraw this month, crossed as the *fact*
          # rather than as a list of reading names for the controller to check
          # itself against. It was a list, and a fourth reading was added
          # without joining it — so `daily` fell through into a redraw it has
          # no payload for.
          "data-shadcn--event-calendar-client-drawn-value" => client_drawn?,
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
          "data-shadcn--event-calendar-event-count-value" => event_count_forms.to_json,
          # One value rather than three, and templates rather than sentences —
          # the same shape `day_label` crosses in, for the same reason. Omitted
          # entirely when nothing moves, like the switch above: a calendar that
          # never says any of this should not carry the strings.
          "data-shadcn--event-calendar-move-labels-value" => (move_labels.to_json if movable?)
        }.compact.merge(defaults))
      end

      def call
        render_element(body: safe_join([ header, grid, (agenda if agenda?), announcer,
                                        (prototypes if client_drawn?) ].compact))
      end

      private

      # Bars and a "+N" from `sm` up, or marks at every width. Decided per
      # calendar rather than per cell, because two cells in one grid made of
      # different things would read as two kinds of day.
      def labelled? = reading == :auto && schedule.busiest <= DENSE_ABOVE

      # One `Date.current` per render rather than one per call site: it resolves
      # a time zone each time, and four places ask.
      def today = @today ||= Date.current

      def default_selection
        today.between?(month.first, month.last) ? today : month.first
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

      def move_labels
        { picked: shadcn_t("event_calendar.picked", title: "%{title}"),
          moved: shadcn_t("event_calendar.moved", title: "%{title}", date: "%{date}"),
          returned: shadcn_t("event_calendar.returned", title: "%{title}", date: "%{date}") }
      end

      # A move needs somewhere to be said, and it cannot be the title: that is
      # the calendar's other `role="status"`, it holds the month, and the
      # controller rewrites it on every navigation. So a region of its own,
      # empty until something happens in it.
      def announcer
        return unless movable?

        tag.div("", "data-slot": "event-calendar-announcer", class: "sr-only",
                role: "status", "aria-live": "polite",
                "data-shadcn--event-calendar-target": "announcer")
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
            (preferences_dialog if preferences?),
            nav_button(today, size: :sm, action: "click->shadcn--event-calendar#today") do
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
      # The panel's trigger is an icon, `settings-2`, which shadcn's tasks
      # example puts on its data table's "View" menu. That example is not
      # vendored here, so nothing in this repo checks it. It used to say where you are in a
      # sentence ("Giornaliero · Timeline ed elenco · Per assegnatario"), which
      # on a phone ended in an ellipsis and took the nav a line of its own.
      # The sentence is still its name, `sr-only` as the sidebar trigger's is,
      # and what it said is still the checked items in the menu it opens.
      def view_panel
        render(DropdownMenu::Component.new(align: :start)) do |dropdown|
          dropdown.with_trigger(class: Button::Component.variant_classes(variant: :outline, size: :"icon-sm")) do
            safe_join([
              render(Icon::Component.new("settings-2")),
              tag.span(view_label, class: "sr-only")
            ])
          end
          dropdown.with_menu_content(class: "w-56") do
            safe_join([ period_options, (view_options if view_choices.any?), *reading_options,
                        (preferences_item if preferences?) ].compact)
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
        href = view_url&.call(name)

        render(DropdownMenu::RadioItem::Component.new(
          value: name, checked: name == period,
          **(href ? { as: :a, href: } : { "data-action": "click->shadcn--event-calendar#changeView" })
        )) { shadcn_t("event_calendar.period.#{name}") }
      end

      def daily? = view == :daily

      # Which of `PERIODS` this reading is. The panel decided it with
      # `(name == :daily) == daily?` — a comparison that can only ever answer
      # for two, and the reason a third could not be added without this.
      def period = :monthly

      def view_options
        safe_join([
          render(DropdownMenu::Label::Component.new) { view_heading },
          render(DropdownMenu::Separator::Component.new),
          render(DropdownMenu::RadioGroup::Component.new) do
            safe_join(view_choices.map { |name| view_option(name) })
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

      # The views this period offers, and what the panel calls the question.
      # A month has all three; a week overrides both in `Week`; a day has one
      # view and so no question at all.
      def view_choices = VIEWS

      def view_heading = shadcn_t("event_calendar.view.label")

      # The trigger says where you are and what you are seeing — the two things
      # the panel decides, so it can be read without opening it.
      def view_label
        where = shadcn_t("event_calendar.period.#{period}")
        here = shadcn_t("event_calendar.view.#{view}") if view_choices.any?

        safe_join([ where, here, reading_label ].compact, " · ")
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
      # its controller packs a month the server never rendered. The others do
      # not: their cells hold crews, clients and clock times that
      # `#portable_events` cannot carry, so the controller returns before
      # drawing and the month changes by URL.
      #
      # Named as a fact rather than listed as readings, and crossed to the
      # controller as one, because the list is what went stale: `daily` was
      # added and the guard still named only two.
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

      # What a day cell *is* to a screen reader. A month is a grid of them; a
      # single day is a list, and a `gridcell` with no row or grid above it is
      # a role with nothing to belong to.
      def cell_role = "gridcell"

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
          class: DAY_CLASS,
          "data-day": day.iso8601,
          "data-today": ("true" if day == Date.current),
          "data-selected": ("true" if day == selected),
          "data-outside": ("true" if month.outside?(day)),
          role: cell_role,
          # `aria-selected`, present only when true — what the gem's `Calendar`
          # writes. `aria-pressed` made every one of the other forty-one days
          # announce as "toggle button, not pressed", a state a date grid has no
          # meaning for, and it was the only non-toggle in the gem claiming it.
          #
          # And only on a `gridcell`. ARIA does not allow it on a `listitem`,
          # which is what the readings that stack their days use — axe calls it
          # critical. `Daily` has been shipping that violation since it was
          # written, unseen because it has no template preview and the audit
          # walks template previews. The week is the first stacked reading to
          # have one, which is what surfaced it.
          #
          # What goes with it is the announcement of *which* of seven days is
          # the chosen one. `data-selected` still styles it and the day is still
          # a button carrying its whole date; what a stacked reading has no
          # standard way to say is "and this is the one you are on".
          "aria-selected": ("true" if day == selected && cell_role == "gridcell"),
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
        #
        # Every host colour is `:host`, so its property is the second key: two
        # of them band apart, as two fixed colours do, in an order both halves
        # can compute — a plain string comparison, which is what the
        # controller's `<` does on an ASCII name.
        on_day.sort_by.with_index do |event, index|
          [ COLOR_RANK.fetch(event.color, COLORS_END), event.color_property.to_s, index ]
        end
      end

      # A host's own colour, as the two properties the `data-color` rules set
      # for a fixed one. Inline, so it beats those descendant rules without
      # touching them; the ink stays `--foreground` because a host's colour has
      # no readable pair derived from it. Empty for a fixed colour, so those
      # render byte-identical to before. The name is validated in `Event`.
      def color_style(event)
        return "" unless event.color == :host

        "--event-color:var(#{event.color_property});--event-ink:var(--foreground);"
      end

      def tick(event, on_day, index)
        tag.span(
          "",
          "data-slot": "event-calendar-day-tick",
          "data-color": event.color,
          style: color_style(event).presence,
          "data-run-before": ("true" if index.positive? && same_band?(on_day[index - 1], event)),
          "data-run-after": ("true" if same_band?(on_day[index + 1], event))
        )
      end

      # A colour is the name *and*, for a host's, the property it names: every
      # host colour is `:host`, and two of them are no more one band than blue
      # and rose are.
      def same_band?(other, event)
        other && other.color == event.color && other.color_property == event.color_property
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
        time = chip_time(event)

        tag.div(
          safe_join([
            (if movable?
               tag.span("", "data-slot": "event-calendar-event-grip", class: EVENT_GRIP_CLASS,
                        "data-action": "pointerdown->shadcn--event-calendar#grab")
             end),
            (tag.span("", "data-slot": "event-calendar-event-dot", class: EVENT_DOT_CLASS) unless event.all_day?),
            # Bound once. `chip_time` formats through `I18n.l`, and asking twice
            # per bar — once for the guard and once for the value — is the same
            # duplication `portable_events` had measured at 117 ms of a 155 ms
            # render, left behind here when that one was fixed.
            (tag.span(time, "data-slot": "event-calendar-event-time", class: EVENT_TIME_CLASS) if time),
            tag.span(event.title, "data-slot": "event-calendar-event-title", class: EVENT_TITLE_CLASS)
          ].compact),
          "data-slot": "event-calendar-event",
          "data-event-id": (event.id if movable?),
          class: [ EVENT_CLASS, (EVENT_MOVING_CLASS if movable?) ],
          # The one place this component positions with a style rather than a
          # class, and the reason is the controller: `col-start-#{n}` cannot be
          # built at runtime on either side — Tailwind never sees it here, and
          # a controller that carried the seven spellings would own classes,
          # which is the thing its second rule forbids. Grid line numbers are
          # what those classes compile to anyway, so both sides write the same
          # two declarations and cannot drift.
          style: "#{color_style(event)}grid-column:#{segment.column} / span #{segment.span};grid-row:#{segment.lane}",
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
                   "data-action": ("keydown->shadcn--event-calendar#agendaKeydown" if movable?),
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

      # The `<li>` is the tab stop of a movable row only when nothing inside it
      # is: a row with a url is already a link, and a stop around a stop was
      # two of them for one row, with Enter doing nothing on the outer one.
      # Space reaches `agendaKeydown` from the link just the same, because the
      # list is what listens.
      #
      # `prototype:` is the `<template>`'s, and draws every part a row can
      # have, empty — see `#prototypes`.
      def agenda_item(event, prototype: false)
        tag.li(agenda_row(event, prototype:), "data-slot": "event-calendar-agenda-item", "data-color": event.color,
               style: color_style(event).presence, "data-event-id": (event.id if movable?),
               class: (AGENDA_PICK_CLASS if movable?), tabindex: ("0" if movable? && event.url.blank?))
      end

      # The row *is* an `Item` — a content, a title and a description was the
      # shape it had already, spelled out by hand. Rendering the family instead
      # means the vocabulary is upstream's, and the rules `Item` carries for its
      # own parts keep working.
      def agenda_row(event, prototype: false)
        body = safe_join([
          tag.span("", "data-slot": "event-calendar-agenda-mark",
                   class: [ AGENDA_MARK_CLASS, (AGENDA_MARK_GRIP_CLASS if movable?) ],
                   "data-action": ("pointerdown->shadcn--event-calendar#grabRow" if movable?)),
          render(Item::Content::Component.new(class: AGENDA_CONTENT_CLASS).with_content(
          safe_join([
            render(Item::Title::Component.new(class: AGENDA_EVENT_TITLE_CLASS)
                                         .with_content(agenda_title(event, prototype:))),
            render(Item::Description::Component.new(class: AGENDA_META_CLASS)
                                              .with_content(agenda_meta(event))),
            agenda_description(event, prototype:)
          ].compact)
          )),
          agenda_avatars(event)
        ].compact)

        # The `<li>` carries the colour and this carries the classes, because
        # only one of the two can be an `<a>` and a clone cannot change its own
        # tag name — which is why the `<template>` at the bottom holds both.
        return render(agenda_item_component.with_content(body)) if event.url.blank?

        render(agenda_link(event).with_content(body))
      end

      # The host's attributes go on the link and nowhere else — a row with no
      # url has no link, and the `<li>` is the list's own. Merged with the
      # gem's precedence: the caller's hash after the component's defaults, and
      # `href` and `data-slot` after that, so a host cannot move the row off the
      # event's address or out of its slot. `class`, `data-action` and
      # `data-controller` join.
      #
      # The class is handed on as the list `merge_attributes` built, so Item's
      # own `css_classes` resolves a host's Hash or Array the way it resolves
      # any caller's. `as:` and `size:` are Item's arguments, not attributes,
      # and are dropped from the host's hash so they stay the row's.
      def agenda_link(event)
        merged = merge_attributes({ "class" => "#{AGENDA_ITEM_CLASS} #{AGENDA_LINK_CLASS}" },
                                  event.attributes.to_h.except(:as, :size, "as", "size"),
                                  { "href" => event.url, "data-slot" => "event-calendar-agenda-row" })
        Item::Component.new(**merged.symbolize_keys, size: :sm, as: :a)
      end

      # The title and the subtitle share one truncated line, the flags beside
      # them. Plain title text when there is nothing else, so a row that says
      # no more than it did renders as it did.
      def agenda_title(event, prototype: false)
        extras = [ agenda_subtitle(event, prototype:), *flag_icons(event, "event-calendar-agenda") ].compact
        return event.title if extras.empty?

        safe_join([ event.title, *extras ], " ")
      end

      # `prototype:` draws the part with nothing in it: `Event` turns a blank
      # subtitle into none, so an empty one cannot be asked for any other way.
      def agenda_subtitle(event, prototype: false)
        return if event.subtitle.blank? && !prototype

        tag.span(event.subtitle.to_s, "data-slot": "event-calendar-agenda-subtitle", class: SUBTITLE_CLASS)
      end

      def agenda_description(event, prototype: false)
        return if event.description.blank? && !prototype

        render(Item::Description::Component.new(class: AGENDA_META_CLASS,
                                                "data-slot": "event-calendar-agenda-description")
                                           .with_content(event.description.to_s))
      end

      def agenda_avatars(event)
        return if event.assignees.empty?

        tag.span(chip_avatars(event), "data-slot": "event-calendar-agenda-avatars", class: AGENDA_AVATARS_CLASS)
      end

      def agenda_item_component(**attributes)
        Item::Component.new(size: :sm, "data-slot": "event-calendar-agenda-row",
                            **{ class: AGENDA_ITEM_CLASS }.merge(attributes))
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
            agenda_item(prototype_row_event, prototype: true),
            agenda_item(prototype_row_event(url: "#"), prototype: true)
          ]),
          "data-shadcn--event-calendar-target": "prototypes"
        )
      end

      # Timed rather than all-day, and that is the whole point of it: an
      # all-day chip renders neither a dot nor a time, and the controller
      # cannot clone a child that was never there. It removes the two it does
      # not need instead, which is the direction that works.
      def prototype_event = Event.new(title: "", starts_at: month.first.in_time_zone)

      # The row's shape, with every part it can have, for the same reason the
      # chip's is timed: the clone fills or removes, it never builds. Both
      # badges, one face with a picture, and one face past `AVATARS_CAP` so the
      # count is there — the controller reads the cap back off the number of
      # faces, rather than carrying a copy of the constant.
      #
      # All of it sits inside the `<template>`, inert and never painted, which
      # is why the goldens may move there and nowhere else.
      def prototype_row_event(url: nil)
        faces = [ Event::Assignee.new("", "", :done), Event::Assignee.new("", nil, :pending) ]
        faces += Array.new([ AVATARS_CAP + 1 - faces.size, 1 ].max) { Event::Assignee.new("", nil, nil) }

        Event.new(title: "", starts_at: month.first.in_time_zone, url:, done: true, attachment: true,
                  assignees: faces)
      end

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
        rows = client_rows?

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
            url: event.url.presence,
            # The bars and the marks wear it, so it crosses whenever it is set.
            colorProperty: event.color_property,
            # An empty hash rather than `**nil`, which only Ruby 3.4 accepts.
            **(rows ? portable_row(event) : {})
          }.compact
        end
      end

      # Whether the controller ever builds an agenda row — the same condition
      # its `agendaList` target is written under. With `day_url:` the agenda is
      # the server's, and with `agenda: false` there is none, so what only a
      # row reads would be paid for and never read: the `panel` preview's
      # month carried every assignee of every appointment, for a Sheet.
      def client_rows? = agenda? && day_url.nil?

      # What a row says beyond the title, each only when the event says it —
      # the same trim as `#portable_events`, for the same two thousand events.
      def portable_row(event)
        { subtitle: event.subtitle,
          description: event.description,
          done: (true if event.done?),
          # The host's words for a flag, beside it rather than in its place, so
          # `done: true` still reads as it always has to whoever reads it.
          doneLabel: event.done_label,
          attachment: (true if event.attachment?),
          attachmentLabel: event.attachment_label,
          assignees: (portable_assignees(event) if event.assignees.any?),
          # Only with a url: without one the row has no link to put them on,
          # and the server drops them too.
          attributes: (portable_attributes(event).presence if event.url.present?) }
      end

      # The initials cross already worked out, like the times: they are a rule
      # about names, and the controller would otherwise need its own copy.
      def portable_assignees(event)
        event.assignees.map do |assignee|
          { name: assignee.name, initials: assignee.initials, image: assignee.image&.to_s.presence,
            status: assignee.status, label: assignee.label }.compact
        end
      end

      # Written out the way `tag` writes them — `data: { turbo_frame: }` as
      # `data-turbo-frame`, a non-string `data-` value as JSON, an `aria-` list
      # joined — so the controller only ever sets attributes and never learns
      # Rails' nesting. Normalised by `merge_attributes` first, which is what
      # the server's row goes through, so `data: { action: }` arrives as the
      # `data-action` the clone concatenates. `href` and `data-slot` are the
      # row's own and never cross, and neither do `as`/`size`, which
      # `#agenda_link` keeps from the server's row.
      #
      # A name is escaped the way `tag` escapes it, so it arrives as the server
      # row's spelling of it: `setAttribute` throws on a name no element can
      # carry (`"on click"`), and one throw is the whole redraw.
      def portable_attributes(event)
        pairs = merge_attributes(event.attributes.to_h.except(:as, :size, "as", "size")).flat_map do |name, value|
          next [ [ name, value ] ] unless %w[data aria].include?(name) && value.is_a?(Hash)

          value.map { |key, inner| [ "#{name}-#{key.to_s.dasherize}", inner ] }
        end

        pairs.to_h { |name, value| [ ERB::Util.xml_name_escape(name), flat_value(name, value) ] }
             .compact.except("href", "data-slot")
      end

      # `nil` is an attribute `tag` leaves out, and so is a false boolean one.
      def flat_value(name, value)
        return if value.nil?
        return (name if value) if ActionView::Helpers::TagHelper::BOOLEAN_ATTRIBUTES.include?(name)
        return value.to_json if name.start_with?("data-") && !value.is_a?(String) && !value.is_a?(Symbol)
        return ActionView::Helpers::TagHelper.build_tag_values(value).join(" ") if value.is_a?(Array) || value.is_a?(Hash)

        value.to_s
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

      # The host's long date, with its day unpadded: the name has to contain
      # the "3" the button shows, and "August 03" does not — a voice-control
      # user saying "click 3" has nothing to match (WCAG 2.5.3; axe's
      # `label-content-name-mismatch`). Substituted rather than written out so
      # a host's own order and words survive; `%-d` is a token the
      # controller's `strftime` shim knows, so the browser writes it the same.
      def day_format = "%A, #{I18n.t('date.formats.long').gsub('%d', '%-d')}"

      def agenda_format = shadcn_t("event_calendar.agenda_format")
    end
  end
end
