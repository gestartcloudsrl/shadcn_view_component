# frozen_string_literal: true

require "spec_helper"
require_relative "support/shadcn_source"
require "cgi"
require "set"

# The other direction from `parity_spec.rb`. That one asks whether every class
# upstream emits is present here; this one asks whether every class *we render*
# still exists upstream at all. Without it, a class shadcn deletes stays in the
# port forever and nothing complains.
#
# Two earlier designs were measured and rejected, and the reasons matter because
# they shaped this one:
#
# 1. **Per-family token sets from Ruby string literals.** 12 of 13 families came
#    back dirty: `select-item`, `chevron-down` and `more-horizontal` are all
#    shaped like Tailwind utilities, so slot names, icon names and constants
#    counted as classes.
# 2. **Per-slot, against the slot's own TSX file.** 56 of 145 slots dirty, all
#    of one shape: upstream writes `<DialogTrigger asChild><Button …>`, so
#    Button's classes land on `dialog-trigger` while living in `button.tsx`.
#    Fixing that needs a composition table per slot — the exception table whose
#    absence was the point.
#
# What is left compares the classes we *render* on each `data-slot` against the
# whole vendored corpus. Composition stops being a false positive, because
# Button's classes are in the corpus wherever they land. The trade is that it
# catches a class only when it survives nowhere upstream — a narrower net than
# per-slot, but one that needs no table of which component wraps which.
#
# It is not a substitute for `snapshot_spec.rb`, which is what notices a class
# moving between parts.
RSpec.describe "reverse parity" do
  # Rendered classes, per `data-slot`, from the snapshots — which are real
  # output, so a class attribute cannot contain a constant or an icon name the
  # way a Ruby string literal can.
  def rendered_by_slot
    Dir[Pathname(__dir__).join("fixtures/snapshots/*.html")].each_with_object(
      Hash.new { |hash, key| hash[key] = Set.new }
    ) do |path, slots|
      # The whole tag, not what follows `data-slot`. Reading forward only meant
      # an element that wrote its class *first* was silently unchecked — and
      # nothing said so, because an unchecked slot looks exactly like a clean
      # one. Sixty-eight elements were, across eight slots, `toast-title` and
      # `toast-description` among them: the very family whose exemption block
      # this spec cites as its precedent.
      #
      # `[^>]*` is safe because every `>` a Rails-rendered attribute can hold —
      # `click->…`, `[&>span]:…` — arrives here as `&gt;`.
      File.read(path).scan(/<[a-zA-Z][^>]*>/) do |element|
        slot = element[/\sdata-slot="([^"]*)"/, 1]
        classes = element[/\sclass="([^"]*)"/, 1]
        slots[slot].merge(CGI.unescapeHTML(classes).split(/\s+/)) if slot && classes
      end
    end
  end

  # Every token in every vendored TSX, `examples/` included — the theming
  # components are ported from there, and leaving them out made ModeSwitcher's
  # classes look invented.
  def upstream_corpus
    Dir[Pathname(__dir__).join("../vendor/shadcn/**/*.tsx")].each_with_object(Set.new) do |path, corpus|
      # Through `ShadcnSource` rather than a regex of its own: a class written
      # with `String.raw` lives in a backtick literal, and a scanner that reads
      # only `"…"` calls it invented. The two directions share one idea of what
      # a string literal is, so they cannot drift.
      ShadcnSource.string_literals(File.read(path)).each { |literal| corpus.merge(literal.split(/\s+/)) }
    end
  end

  # Classes this port renders that no vendored source contains. Every one is
  # here on purpose, and the spec fails if that stops being true in either
  # direction — a new one appears, or a listed one goes away.
  #
  # Three kinds, and the first is the price of reading snapshots: a preview is a
  # caller, and callers may add classes.
  # A local, not a constant: a constant declared in a describe block lands on
  # Object. `LeakyLocalVariable` is off here for exactly this.
  ours = {
    # Sizing a preview passes in to demonstrate the component at a sensible
    # width. Nothing to do with the port.
    "accordion" => %w[w-[420px]],

    # The width the four cartesian chart previews give their card. A pie is
    # square and fits a narrow one; an axis of six months wants the room, and
    # `Plot` draws into a 560px box.
    "card" => %w[max-w-xl],

    "field-group" => %w[w-[420px]],
    "tabs" => %w[w-[420px]],
    "select-trigger" => %w[w-[200px] w-[220px] w-[240px]],
    # The two floating panels the previews size at the call site, for the same
    # reason the dropdown's content is sized above: a panel does not know how
    # wide its contents want to be.
    "popover-content" => %w[w-56],
    "hover-card-content" => %w[w-56],
    # A vertical slider is as long as the caller makes it — the component sets
    # no length on either axis, which is what lets the same one lie down.
    "slider" => %w[h-48],
    # The scrolling-dialog preview, and the only three classes in the gallery
    # that are a *technique* rather than sizing. A dialog whose body scrolls has
    # to say which grid row gives (`grid-rows-[auto_1fr_auto]`), cap its own
    # height (`max-h-[80vh]`) and drop the gap that would show through a flush
    # header. None is upstream's markup: they are what a caller adds, and the
    # preview exists to show that they are needed. See the preview's own
    # comment for the `min-h-0` that goes with them, which lands on a plain div
    # and so never reaches this spec.
    "dialog-content" => %w[gap-0 grid-rows-[auto_1fr_auto] max-h-[80vh]],
    # Both from the calendar previews, and both are what upstream's own examples
    # do at the call site rather than in the component. "Custom Cell Size" is a
    # calendar sized from one custom property, and "Booked dates" strikes the
    # taken days through — upstream reaches for `modifiers` and
    # `modifiersClassNames` there, which this port does not have, so the same
    # cells are reached with a class on the root.
    "calendar" => [ "[--cell-size:--spacing(12)]", "[&_td[data-disabled]>button]:line-through" ],
    # The height upstream's own pie examples give the container at the call
    # site — `className="mx-auto aspect-square max-h-[250px]"`. Here the shape
    # defaults to it, because a pie that fills whatever box it is in is not a
    # useful default; the other two classes are in the corpus already.
    "chart-pie" => %w[max-h-[250px]],
    # The pair `Icon::Component` stamps wherever upstream mounts a lucide React
    # component — the same reason the other icon slots are listed here.
    "combobox-trigger-icon" => %w[lucide lucide-chevron-down],
    # The width upstream's own docs example gives the palette at the call site.
    "command" => %w[md:min-w-[450px]],
    # The previews' own sizing: a group of panels is as big as its caller makes
    # it, which is the whole point of a layout component.
    "resizable-panel-group" => %w[max-w-md md:min-w-[450px] min-h-[200px]],
    "skeleton" => %w[size-12 w-[200px] w-[250px]],
    "empty" => %w[max-w-md],
    "item" => %w[max-w-md],
    "item-group" => %w[max-w-md],
    "separator" => %w[my-4 my-2],
    # A hover card usually hangs off something already in a sentence, so the
    # preview's trigger is an underlined link. Caller styling, like the widths
    # above.
    "hover-card-trigger" => %w[underline],
    # The two boxes the scroll-area preview scrolls. A scroll area is `relative`
    # and nothing else — it is the caller who says how big the window is, which
    # is the whole point of the component.
    "scroll-area" => %w[h-64 w-48],
    # The width the preview gives a navigation panel. Upstream's own example
    # sizes them at the call site too — a menu does not know how wide its
    # contents want to be.
    "navigation-menu-content" => %w[md:w-[400px]],
    # The preview's own region and panel widths. Upstream gives the context
    # trigger no classes at all — it is an area to right-click, and how big it
    # is can only come from the caller.
    "context-menu-trigger" => %w[h-40],
    "context-menu-content" => %w[w-52],
    # A named Tailwind group the sidebar preview passes to a Collapsible, so a
    # menu item's chevron can rotate when its own section opens. Upstream's
    # sidebar demo does the same, but demos are not vendored here — only
    # `ui/*.tsx` and `examples/` are — so the token exists in no source this
    # spec can see.
    "collapsible" => %w[w-[420px] group/collapsible],

    # The searchable select, which is this gem's own component rather than a
    # port — no Radix base has one. Its classes come from shadcn's React Aria
    # variant, which is not vendored here, or from this port outright.
    # See decisions/01-architecture.md.
    "select-item" => %w[data-[highlighted]:bg-accent data-[highlighted]:text-accent-foreground],
    "select-list" => %w[group/select-list max-h-[inherit]],
    "select-input-wrapper" => %w[pb-0],

    # Upstream renders a Sheet below `md` and this panel above it, so its
    # classes never have to describe a phone. Here there is one tree and the
    # sheet *is* this panel, so the mobile branch has to be said in CSS: the
    # container turns visible at upstream's `SIDEBAR_WIDTH_MOBILE`, and the
    # spacer that reserves the panel's width in the page stops reserving it,
    # because a sheet overlays the page rather than sitting beside it.
    # `z-50` and `shadow-lg` are `sheet-content`'s own (sheet.tsx:63) and the
    # slide classes beside them are too — those pass this spec unprefixed,
    # because they are upstream's strings. These two carry the mobile prefix
    # only because the same element is the desktop panel the rest of the time.
    "sidebar-container" => %w[
      group-data-[mobile=true]:flex group-data-[mobile=true]:w-(--sidebar-width-mobile)
      group-data-[mobile=true]:z-50 group-data-[mobile=true]:shadow-lg
    ],
    "sidebar-gap" => %w[group-data-[mobile=true]:w-0],

    # The two conditions upstream writes as a React prop on the sidebar menu
    # button's tooltip — `hidden={state !== "collapsed" || isMobile}`
    # (sidebar.tsx:541). Neither is knowable when the server renders, so here
    # they are classes reading the panel's own attributes. The tokens are this
    # port's, and exist in no TSX for that reason. See features/sidebar.md.
    "tooltip-content" => %w[group-data-[mobile=true]:hidden group-data-[state=expanded]:hidden],

    # One of the six utilities in `shadcn.css` that are shadcn's own CSS rather
    # than Tailwind's, read from the stylesheet ui.shadcn.com serves because no
    # vendored source defines them. `attachment` reaches for it through a
    # `data-state` selector, which never puts the word in any markup; the
    # marker's status preview is the one place the gallery writes it out, and so
    # the one place it is looked at.
    "marker-content" => %w[shimmer],

    # The inset preview overriding the wrapper's background, which upstream
    # paints `bg-sidebar` so the panel and the page read as two cards floating
    # on the sidebar's colour. Asked for here, and a caller's class rather than
    # a change to the component: `parity_spec` still finds upstream's string in
    # the source, and a host that passes nothing gets upstream's look.
    "sidebar-wrapper" => %w[has-data-[variant=inset]:bg-background],

    # The carousel previews. `basis-1/2` and `basis-1/3` are upstream's own
    # instruction for its "Sizes" example — the component has no prop for how
    # many slides are visible, and says so — and the gutter in "Spacing" is the
    # same arrangement one notch smaller. The width and the height are a preview
    # deciding how big to be, like every other in this list.
    "carousel" => %w[max-w-xs],
    "carousel-content" => %w[-ml-2 h-[240px]],
    "carousel-item" => %w[basis-1/2 basis-1/3],

    # The whole toaster family, and it is here in full rather than waved
    # through: `sonner.tsx` emits no markup at all, so every class this port
    # renders for it is this port's. Listed one by one so that a class added
    # *tomorrow* still has to be explained — a blanket exemption would make the
    # only component with no upstream the only one nobody checks.
    #
    # The colours are the one judgement: sonner paints its icons by variant and
    # its own palette is not in any vendored source, so these are Tailwind's
    # nearest and are named here as a decision rather than a copy.
    "toast" => %w[[&_[data-slot=toast-icon]]:animate-spin [&_[data-slot=toast-icon]]:text-amber-600 [&_[data-slot=toast-icon]]:text-blue-600 [&_[data-slot=toast-icon]]:text-destructive [&_[data-slot=toast-icon]]:text-emerald-600 dark:[&_[data-slot=toast-icon]]:text-amber-400 dark:[&_[data-slot=toast-icon]]:text-blue-400 dark:[&_[data-slot=toast-icon]]:text-emerald-400 data-[state=closed]:opacity-0 duration-[400ms] pointer-events-auto shadow-[0_4px_12px_rgba(0,0,0,0.1)] text-[13px]],
    "toast-icon" => %w[lucide lucide-circle-check lucide-info lucide-loader-circle lucide-octagon-x lucide-triangle-alert],
    "toaster" => %w[bottom-6 group/toaster right-6 top-6 z-[100]],

    # `Icon::Component` stamps `lucide lucide-<name>` itself, where upstream
    # mounts a React component whose classes never appear in the TSX text.
    "native-select-icon" => %w[lucide lucide-chevron-down],

    # The whole event-calendar family, and — like the toaster's above — listed
    # one slot at a time rather than waved through. There is no upstream event
    # calendar at all: `calendar.tsx` is the day picker, so nothing this family
    # renders can be a copy of anything, and a blanket exemption would make the
    # newest component the one nobody checks.
    #
    # Most of what is listed is the same two kinds as everywhere else — a size
    # upstream never needed (`min-h-14`, `h-5.5`, `top-8`, `auto-rows-…`), and a
    # breakpoint upstream never has to write because React renders the phone and
    # the desktop as two trees where this renders one. Three are judgements:
    #
    # 1. `group/event-calendar` and its `sm:group-data-[overflow]` partner. A
    #    cell reserves a row for its "+2" line only in a month that has one, and
    #    whether the month has one is not knowable from inside a cell.
    # 2. The colour custom properties. An event's colour is *data*, so it cannot
    #    be a Tailwind class — Tailwind never sees a string built at runtime —
    #    and it cannot be a hex either, because a hex has no answer for the dark
    #    palette. Two properties per name, declared once on the root, is what is
    #    left. See `Component::COLOR_TOKENS`.
    # 3. `bg-[var(--event-color)]/12` and `text-(--event-ink)`, which read them.
    #
    # The `rows:` block below is the rows-are-days spike: the workload reading
    # is one row per day when it is narrow or when the toolbar says so, and the
    # seven-column month otherwise. Declared as descendant rules on the root for
    # the same reason the colours are, and inert on any calendar that is not the
    # workload reading. `rows:` is the gem's own variant, declared in
    # `shadcn.css` beside `dark`; it carries the breakpoint *and* the override,
    # so each rule below is written once. The default is still a width decision
    # a server cannot make — `arrangement:` only overrules it.
    #
    # A row is a fixed 80px and its chips scroll sideways inside it, which is
    # where the `overflow-x`, `overscroll`, `touch-pan-x` and scrollbar-hiding
    # rules come from — and `shrink-0` on the chips, without which they squash
    # to fit and the strip never overflows at all.
    # The hours reading's own parts. None of these had ever been read by a
    # spec: the reading had only a method preview, so no fixture existed and
    # this file — which globs the fixtures — could not see them. Adding
    # `previews/hours.html.erb` is what surfaced them.
    #
    # The ruler is the hour scale, drawn once above the month rather than once
    # per row: it is the same hours on every row and forty-two copies would be
    # forty-two chances to disagree. Its pad is the width of the date column,
    # so tick zero starts where the tracks do.
    "event-calendar-ruler" => %w[pb-1 text-[0.6rem]],
    "event-calendar-ruler-pad" => %w[w-14],
    # The axis itself. The gridlines are a repeating gradient rather than
    # twenty-four elements, because they are decoration and a DOM node each
    # would be a thousand of them in a month — spaced by `--gridline`, which is
    # one mark's share, so the lines and the labels above them are the same
    # divisions. It was a flat 12.5% and a 07–19 axis drew six labels against
    # eight lines. Its height is its lanes: a day
    # is as tall as the deepest stack of overlapping jobs it has.
    "event-calendar-day-track" => %w[
      bg-[repeating-linear-gradient(to_right,var(--border)_0_1px,transparent_1px_var(--gridline))]
      h-[calc((var(--lanes)*var(--lane-h))+0.35rem)]
    ],
    # A bar is placed and sized by the clock: `--at` is its start as a share of
    # the window, `--for` its duration, `--lane` which row of the stack it got.
    # `min-w-[3px]` is the floor at which a job is still a mark rather than
    # nothing — a fifteen-minute call on a sixteen-hour axis is under a pixel.
    "event-calendar-day-bar" => %w[
      bg-[var(--event-color)]/70 left-(--at) min-w-[3px] top-(--lane) w-(--for)
      data-[continues-before]:rounded-s-none data-[continues-after]:rounded-e-none
      data-[continues-before]:border-s-2 data-[continues-before]:border-s-[var(--event-color)]
      data-[continues-after]:border-e-2 data-[continues-after]:border-e-[var(--event-color)]
    ],
    # How long a job that crosses days runs, beside the clock of the day it is
    # drawn on — `date_span`, the same phrasing the agenda uses.
    "event-calendar-day-span" => %w[shrink text-[0.65rem]],
    # The hours reading's layout, which now lives on `Hours::Component` and
    # only ever lands on its root — so these carry no `data-[track]:` guard any
    # more. They used to, because every reading shared one class string and a
    # plain calendar was carrying all twenty-two of them: the guard was the
    # symptom, and the split is what removed the need for it.
    # The band closes up: on the side a chip was cut, it takes back the cell's
    # padding and half the grid line, so five days of one job read as one strip.
    # `w-auto` is load-bearing — the chip carries `w-full`, and a box with an
    # explicit width does not grow when given a negative margin. `not-rows:`
    # because in a row a day has no neighbour to meet.
    "event-calendar" => %w[
      not-rows:[&_[data-slot=event-calendar-day-item][data-continues-before]]:-ms-[calc(var(--spacing)*1.5_+_0.5px)]
      not-rows:[&_[data-slot=event-calendar-day-item][data-continues-before]]:w-auto
      not-rows:[&_[data-slot=event-calendar-day-item][data-continues-after]]:-me-[calc(var(--spacing)*1.5_+_0.5px)]
      not-rows:[&_[data-slot=event-calendar-day-item][data-continues-after]]:w-auto
      group/event-calendar
      [--event-calendar-hour:0px]
      max-lg:[--event-calendar-hour:22vw]
      [&_[data-slot=event-calendar-grid]]:overflow-x-auto
      [&_[data-slot=event-calendar-weeks]]:min-w-(--event-calendar-track)
      [&_[data-slot=event-calendar-ruler]]:min-w-(--event-calendar-track)
      [&_[data-slot=event-calendar-day]]:min-h-14
      [&_[data-slot=event-calendar-day]]:items-start
      [&_[data-slot=event-calendar-day-head]]:sticky
      [&_[data-slot=event-calendar-day-head]]:left-0
      [&_[data-slot=event-calendar-day-head]]:z-10
      [&_[data-slot=event-calendar-day-head]]:self-stretch
      [&_[data-slot=event-calendar-day-head]]:justify-start
      [&_[data-slot=event-calendar-day-head]]:pt-1.5
      [&_[data-slot=event-calendar-day-head]]:bg-background
      [&_[data-slot=event-calendar-ruler-pad]]:sticky
      [&_[data-slot=event-calendar-ruler-pad]]:left-0
      [&_[data-slot=event-calendar-ruler-pad]]:z-10
      [&_[data-slot=event-calendar-ruler-pad]]:self-stretch
      [&_[data-slot=event-calendar-ruler-pad]]:bg-background
      [&_[data-color=default]]:[--event-color:var(--muted-foreground)] [&_[data-color=default]]:[--event-ink:var(--foreground)]
      [&_[data-color=blue]]:[--event-color:var(--color-blue-500)] [&_[data-color=blue]]:[--event-ink:var(--color-blue-800)]
      dark:[&_[data-color=blue]]:[--event-ink:var(--color-blue-300)]
      [&_[data-color=green]]:[--event-color:var(--color-emerald-500)] [&_[data-color=green]]:[--event-ink:var(--color-emerald-800)]
      dark:[&_[data-color=green]]:[--event-ink:var(--color-emerald-300)]
      [&_[data-color=amber]]:[--event-color:var(--color-amber-500)] [&_[data-color=amber]]:[--event-ink:var(--color-amber-800)]
      dark:[&_[data-color=amber]]:[--event-ink:var(--color-amber-300)]
      [&_[data-color=rose]]:[--event-color:var(--color-rose-500)] [&_[data-color=rose]]:[--event-ink:var(--color-rose-800)]
      dark:[&_[data-color=rose]]:[--event-ink:var(--color-rose-300)]
      [&_[data-color=violet]]:[--event-color:var(--color-violet-500)] [&_[data-color=violet]]:[--event-ink:var(--color-violet-800)]
      dark:[&_[data-color=violet]]:[--event-ink:var(--color-violet-300)]

      rows:[&_[data-slot=event-calendar-day-head]]:flex
      rows:[&_[data-slot=event-calendar-day-head]]:flex-col
      rows:[&_[data-slot=event-calendar-day-head]]:gap-1
      rows:[&_[data-slot=event-calendar-day-head]]:items-center
      rows:[&_[data-slot=event-calendar-day-head]]:justify-center
      rows:[&_[data-slot=event-calendar-day-head]]:shrink-0
      rows:[&_[data-slot=event-calendar-day-head]]:w-14
      rows:[&_[data-slot=event-calendar-day-item]]:shrink-0
      rows:[&_[data-slot=event-calendar-day-item]]:w-auto
      rows:[&_[data-slot=event-calendar-day-items]]:[&::-webkit-scrollbar]:hidden
      rows:[&_[data-slot=event-calendar-day-items]]:[scrollbar-width:none]
      rows:[&_[data-slot=event-calendar-day-items]]:flex-nowrap
      rows:[&_[data-slot=event-calendar-day-items]]:flex-row
      rows:[&_[data-slot=event-calendar-day-items]]:min-w-0
      rows:[&_[data-slot=event-calendar-day-items]]:overflow-x-auto
      rows:[&_[data-slot=event-calendar-day-items]]:overscroll-x-contain
      rows:[&_[data-slot=event-calendar-day-items]]:touch-pan-x
      rows:[&_[data-slot=event-calendar-day-items]]:w-auto
      rows:[&_[data-slot=event-calendar-day-label]]:flex
      rows:[&_[data-slot=event-calendar-day-label]]:flex-col
      rows:[&_[data-slot=event-calendar-day-label]]:gap-0
      rows:[&_[data-slot=event-calendar-day-label]]:items-center
      rows:[&_[data-slot=event-calendar-day-label]]:w-full
      rows:[&_[data-slot=event-calendar-day-number]]:text-sm
      rows:[&_[data-slot=event-calendar-day-assignee]]:shrink-0
      rows:[&_[data-slot=event-calendar-day-assignee]]:w-auto
      rows:[&_[data-slot=event-calendar-day-assignees]]:[&::-webkit-scrollbar]:hidden
      rows:[&_[data-slot=event-calendar-day-assignees]]:[scrollbar-width:none]
      rows:[&_[data-slot=event-calendar-day-assignees]]:flex-nowrap
      rows:[&_[data-slot=event-calendar-day-assignees]]:flex-row
      rows:[&_[data-slot=event-calendar-day-assignees]]:min-w-0
      rows:[&_[data-slot=event-calendar-day-assignees]]:overflow-x-auto
      rows:[&_[data-slot=event-calendar-day-assignees]]:overscroll-x-contain
      rows:[&_[data-slot=event-calendar-day-assignees]]:touch-pan-x
      rows:[&_[data-slot=event-calendar-day-assignees]]:w-auto
      rows:[&_[data-slot=event-calendar-day-rest]]:shrink-0
      rows:[&_[data-slot=event-calendar-day-rest]]:w-auto
      rows:[&_[data-slot=event-calendar-day-weekday]]:block
      rows:[&_[data-slot=event-calendar-day][data-outside]]:hidden
      rows:[&_[data-slot=event-calendar-day]]:flex-row
      rows:[&_[data-slot=event-calendar-day]]:gap-2
      rows:[&_[data-slot=event-calendar-day]]:h-20
      rows:[&_[data-slot=event-calendar-day]]:items-center
      rows:[&_[data-slot=event-calendar-day-held]]:hidden
      rows:[&_[data-slot=event-calendar-day]]:min-h-0
      rows:[&_[data-slot=event-calendar-day]]:px-2
      rows:[&_[data-slot=event-calendar-day]]:py-2
      rows:[&_[data-slot=event-calendar-days]]:contents
      rows:[&_[data-slot=event-calendar-segments]]:hidden
      rows:[&_[data-slot=event-calendar-week]]:contents
      rows:[&_[data-slot=event-calendar-weekdays]]:hidden


    ],
    "event-calendar-day-label" => %w[contents],
    "event-calendar-day-weekday" => %w[text-[0.7rem]],
    "event-calendar-title" => %w[sm:text-lg],
    "event-calendar-weekdays" => %w[grid-cols-7],
    "event-calendar-weekday" => %w[sm:text-xs text-[0.7rem]],
    # The 1px rules between cells, drawn as gaps over a `bg-border` parent
    # rather than as borders on each cell — borders double up where two cells
    # meet, and a month grid cannot have lines of two widths.
    "event-calendar-weeks" => %w[gap-px],
    "event-calendar-days" => %w[gap-px grid-cols-7],
    # The selection is an outline as well as a tint, and both halves are
    # measured: `bg-accent` alone separated a selected cell from a plain one by
    # 0.030 of perceptual lightness in the light palette against 0.124 in the
    # dark. An `outline` rather than a second `ring` because a ring is the same
    # property as the focus ring and would have replaced it.
    "event-calendar-day" => %w[
      data-[selected]:[outline:2px_solid_var(--ring)] data-[selected]:[outline-offset:-2px]
      data-[selected]:z-10
      data-[selected]:bg-accent focus-visible:ring-inset hover:bg-accent/50 min-h-14 pb-1 pt-1.5 px-0.5
      sm:group-data-[overflow]/event-calendar:min-h-(--event-calendar-cell-more)
      sm:items-start sm:px-1.5 pt-1
      group-data-[labelled]/event-calendar:sm:min-h-(--event-calendar-cell)
    ],
    "event-calendar-day-number" => %w[
      group-data-[outside]/day:text-muted-foreground
      group-data-[today]/day:bg-primary group-data-[today]/day:font-semibold
      group-data-[today]/day:text-primary-foreground sm:text-[0.8rem]
    ],
    # `top-8` clears the day number, and the row height is one bar plus its gap
    # — the two figures `Component#cell_height` derives a cell's height from.
    "event-calendar-segments" => %w[
      auto-rows-[1.625rem] gap-x-px grid-cols-7 px-px top-8
      group-data-[labelled]/event-calendar:sm:grid
    ],
    # The phone's whole vocabulary: one mark per event, all of them. Every rule
    # a mark obeys is here on the strip rather than on each mark — at eighty
    # events a day the class string below repeated is half a megabyte of HTML
    # for a rule that never varies.
    "event-calendar-day-ticks" => %w[
      content-start gap-px pt-0.5 group-data-[labelled]/event-calendar:sm:hidden
      [&>span]:size-(--event-calendar-tick) [&>span]:shrink-0 [&>span]:rounded-[1px]
      [&>span]:bg-(--event-color)
      [&>span[data-run-after]]:-me-px [&>span[data-run-after]]:rounded-r-none
      [&>span[data-run-before]]:rounded-l-none
    ],
    "event-calendar-day-more" => %w[text-[0.7rem] group-data-[labelled]/event-calendar:sm:block],
    "event-calendar-event" => %w[
      bg-[var(--event-color)]/12 data-[continues-after]:rounded-r-none data-[continues-before]:rounded-l-none
      h-5.5 mx-px text-(--event-ink) text-[0.7rem]
    ],
    "event-calendar-event-dot" => %w[bg-(--event-color) size-1.5],
    "event-calendar-agenda" => %w[mt-3],
    "event-calendar-agenda-title" => %w[pb-1.5 gap-x-2 items-baseline],
    "event-calendar-agenda-row" => %w[focus-visible:outline-none],
    "event-calendar-agenda-mark" => %w[bg-(--event-color)],
    "event-calendar-agenda-empty" => %w[py-8],

    # The workload reading, which had no template preview until now and so was
    # in none of these lists — 450 lines of shipped classes that nothing
    # checked. A cell there is a measure rather than a list: a count chip
    # wearing a sequential ramp, and one chip per assignee or per event.
    #
    # `border-border/40` is the hairline that keeps a chip a chip at the pale
    # end of the ramp; `data-[heavy]:text-primary-foreground` is the ink flip
    # past halfway, which is what let the ramp use its whole length instead of
    # the fifth that keeps dark-on-light readable.
    # The avatar, shrunk a step for the crew stack on a workload chip and given
    # two initials to hold at fourteen pixels: the group's overlap is a quarter
    # of upstream's `size-8`, which on a `size-3.5` is four pixels and not eight.
    "avatar-fallback" => %w[text-[0.5rem]],
    "avatar-group" => %w[-space-x-1],
    "avatar-group-count" => %w[lg:size-4 text-[0.5rem]],
    # The width the day sheet is given at the call site, like every other panel
    # width in this list: a sheet does not know how wide its contents want to be.
    "sheet-content" => %w[sm:max-w-md],
    # The width the grouping menu is given at the call site, like every other
    # panel width in this list.
    "dropdown-menu-content" => %w[w-56],
    "event-calendar-day-count" => %w[border-border/40 data-[heavy]:text-primary-foreground py-0 text-[0.65rem]],
    "event-calendar-day-assignee" => %w[border-border/40],
    # A lane a day does not use, held open so the day that does use it finds it
    # in the same place. It wears a chip's own classes because it is a chip with
    # nothing in it — given a height instead, it came out 45px against a real 53
    # and put the band it was aligning eight pixels off.
    # Nothing of its own any more: the chip's rules moved into
    # `.shadcn-event-calendar-chip` in `shadcn.css`, and an invisible lane is
    # that class plus `invisible`. See the note on `event-calendar-day-item`.
    "event-calendar-day-held" => %w[shadcn-event-calendar-chip],
    # A job that crosses days is drawn on each day it covers, and says so twice:
    # a flat edge on the side it runs off, which is the bars' vocabulary, and a
    # rail of its own colour down the left.
    #
    # The rail is not decoration. The flat edge reads where chips sit in a row —
    # the strip below `lg`, the hours axis — because an edge running off the end
    # of something is a shape you can see. Stacked at full width in a grid cell
    # it says nothing, and two days of one job looked like two jobs.
    #
    # The chip, and — in the hours reading — where the clock puts it. An all-day
    # chip is the one whose width means something: it has no hour to be placed
    # at, so it is the whole axis rather than as wide as its own text — and it
    # carries exactly one of `w-auto` and `w-(--for)`, never both, because this
    # class string does not go through `tailwind_merge`.
    # `shadcn-event-calendar-chip` is the one component class in this port, and
    # the only one there will be while the rest is 1:1 on classes: this chip is
    # ours, so no vendored source owns its rules, and 390 bytes repeated on 68
    # chips was 24 KB of a dense month. `shadcn.css` carries the reasoning.
    #
    # The tokens beside it are the hours reading, which renders this same slot
    # the ordinary way — it draws too few chips for the weight to matter.
    "event-calendar-day-item" => %w[
      shadcn-event-calendar-chip
      bg-[var(--event-color)]/12 border-border/40 text-(--event-ink)
      left-(--at) top-(--lane) max-w-[13rem] w-(--for) min-w-max
      data-[continues-before]:rounded-s-none data-[continues-after]:rounded-e-none
      data-[continues-before]:border-s-2 data-[continues-before]:border-s-[var(--event-color)]
      data-[continues-after]:border-e-2 data-[continues-after]:border-e-[var(--event-color)]
    ],
    "event-calendar-day-time" => %w[pe-2 text-[0.65rem]],
    "event-calendar-day-text" => %w[text-[0.65rem]],
    # The cap is a rule about the fourth chip onwards, scoped by slot so it
    # cannot also catch the "+N" chip sitting last in the column — and the two
    # groupings hide each other, because both are rendered and the menu picks.
    # The event calendar shrinks an avatar a step below upstream's smallest for
    # the crew stack on a workload chip, where five faces share the width of a
    # clock. `size-3.5` is in the corpus; the desktop step up is not.
    "avatar" => %w[lg:size-4],
    "event-calendar-day-rest" => %w[border-border/40 text-[0.65rem]]
  }.freeze

  it "renders no class that has disappeared from every vendored source", :aggregate_failures do
    corpus = upstream_corpus

    # Guards the comparison rather than the port: an extraction that silently
    # stopped matching would make every slot pass.
    expect(corpus.size).to be > 500

    rendered_by_slot.each do |slot, classes|
      unknown = classes - corpus - ours.fetch(slot, [])

      expect(unknown).to be_empty,
                         "#{slot} renders #{unknown.sort.join(' ')}, which no vendored TSX contains. " \
                         "If that is deliberate, add it to `ours` with the reason."
    end
  end

  it "lists nothing as ours that upstream has since adopted" do
    corpus = upstream_corpus
    adopted = ours.transform_values { |classes| classes & corpus.to_a }.reject { |_, v| v.empty? }

    expect(adopted).to be_empty,
                       "these are listed as ours but now appear upstream: #{adopted.inspect}"
  end
end
