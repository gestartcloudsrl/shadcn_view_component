# Chart

*Frame ported 1:1; the drawing is **ours**. Four shapes: pie, bar, line, area.*

This is the one family where the dependency was doing the work, and saying so
plainly is the point of this file.

## `chart.tsx` draws nothing

Its 374 lines are a frame: a container that publishes one custom property per
series, and the *contents* of a tooltip and a legend that `recharts` fills in.
The chart — the SVG, the scales, the axes — is written by the caller in JSX,
importing `recharts` directly. The docs page is, from the first heading to the
last, a tutorial in composing `CartesianGrid`, `XAxis` and `Bar`.

| | |
|---|---|
| recharts 3.10.1 | **29,091 lines** of compiled ES6, 7.1 MB unpacked |
| its dependencies | 11, including `@reduxjs/toolkit` (5.7 MB), `react-redux`, `immer`, `victory-vendor` (the d3 modules) |
| what it does | scales, layout, axes, shapes, animation, and a Redux store for chart state |

Those figures were read from the published tarball — `recharts@3.10.1`'s own
`dist/es6` — and **nothing of recharts is vendored here**, unlike Radix, vaul
and `@shadcn/react`. Nothing in this port cites it line by line, so there was
nothing for a vendored copy to keep honest; a future session should not go
looking for `vendor/recharts`.

The four ports before this one removed a package because the browser already
had the mechanism — scrolling, `touch-action`, an input, date arithmetic. Here
the package **is** the component, so "porting chart" had to mean something
else: reproduce the frame exactly, and draw the shape here.

## What is 1:1

- **`ChartContainer`** — `data-slot="chart"`, `data-chart="chart-…"`, and the
  `<style>` element publishing `--color-<key>` for light and `.dark`. That
  contract is the whole reason the frame is worth porting: a slice says
  `fill="var(--color-chrome)"` and a host restyles the chart from its own
  stylesheet, exactly as it would upstream.
- **`ChartTooltipContent`** — every class, all three indicators (`dot`, `line`,
  `dashed`), `hide_label:`, `hide_indicator:`, and `nestLabel`: with a single
  item and an indicator that is not a dot, the label moves inside the row and it
  bottom-aligns (`chart.tsx:186`).
- **`ChartLegendContent`** — every class, `vertical_align:` and `hide_icon:`.

Upstream renders the tooltip anew on every pointer move, with the hovered
payload. Here it is rendered once, empty, and the controller writes the label,
the name, the value and the indicator's colour into it — the same DOM, arrived
at from the other side.

## What is ours

**The shapes, and the axis under three of them.**

### The pie

An arc is trigonometry and an SVG path, which is why it is the
shape to draw first: no scales, no ticks, no axis labels to collide. `data:` is
a Hash of key to number — what `group(:browser).sum(:visitors)` already hands
back — and `inner_radius:` is a fraction, so the donut keeps its proportions at
any size.

Two cases are worth knowing because they are the ones that break naively:

- **A single slice is a circle, not an arc.** An arc whose two ends are the same
  point draws nothing at all, and a pie of one is what a filter leaves behind.
- **`percentage: true` puts the share where the count would be.** A pie's
  question is usually "how much of the whole", and doing it in the data keeps
  the tooltip 1:1 — upstream's has one cell for a value and no room for a
  second number.

### The cartesian three

`Chart::Plot` is the half that is not a shape: a nice maximum, five ticks, a
band per category, a bar's rectangle, a line's points, and how many category
labels fit. It is a plain object with no view, so all of it is asserted in
`spec/components/shadcn/chart_plot_spec.rb` without a browser — the trade
`Calendar::Month` makes.

`Chart::Cartesian::Component` draws the frame that follows from it — grid, tick
labels, category labels, the accessible name — and `Bar`, `Line` and `Area`
draw over it. `data:` is a Hash of category to a Hash of series to number,
which `group(:month, :platform).sum(:visits)` is one `each_with_object` away
from.

Four decisions in there are worth knowing, and three of them were made by
looking at the rendered gallery rather than by a spec:

- **A bar's axis is a band scale and a line's is a point scale.** Upstream's own
  line and area charts touch both edges of the plot; a bar needs a band to be
  wide in. So the two place their readings — and their category labels —
  differently, and `Plot` has both `x_of`/`band` and `point_x`.
- **The labels at the two ends of a point scale anchor `start` and `end`.**
  Centred, half the word is outside the `viewBox`, which an SVG clips: the line
  chart's last month read "Jun".
- **A stacked bar is a `<path>`, not a `<rect>`.** `rx` takes one number, so a
  rect rounds every corner or none, and a stack needs its seams square — the
  per-corner `radius={[4, 4, 0, 0]}` upstream's docs example passes. A rounded
  seam leaves a notch down the middle of the bar.
- **A line's dot and its hit target are two circles.** Four pixels is a target
  nobody can hold, so a transparent circle takes the pointer events and the
  visible one takes the colour. recharts solves the same problem with an
  invisible cursor rectangle over the band.

The tooltip needed one thing from this: a pie's label and its series name are
the same word, and a bar's are the month it stands in and the device it counts.
So a mark carries `data-label` *and* `data-name`, and the controller falls back
to the label when there is no name — which is what keeps the pie's markup
unchanged.

**A colour is filtered before it reaches the `<style>`.** Upstream writes the
config's colours through `dangerouslySetInnerHTML`, where a `}` would close the
rule and everything after it would be the caller's own CSS running in the host's
page. A library that runs inside an application it cannot see does not get to be
exposed to that, so a colour has to look like one.

## Accessibility: the table is the chart

**The graphic says nothing, and a visually hidden table beside it says all of
it.** Every shape renders `<svg aria-hidden="true">` followed by a `sr-only`
`<table>`: a `<caption>` with the chart's label, a column per series, a row per
category, `th[scope=col]` and `th[scope=row]` on both.

Three earlier versions of this are worth knowing, because each was wrong in a
way the next one fixed:

1. **Each slice with its own `aria-label` and a `tabindex`.** axe was right to
   fail it: `aria-label` on a `<path>` with no role is prohibited.
2. **One `role="img"` whose name was the whole chart** — *"Visitors — January:
   Desktop 186, Mobile 80; February: …"*. Correct, and unusable past a handful
   of numbers: a name is one utterance, so it cannot be navigated, cannot be
   reread in pieces, and a year of months is a paragraph read start to finish
   before the reader can do anything else.
3. **The table, with the name still on the SVG.** Then the data is announced
   twice, once as an image and once as rows.

So it is one or the other, and the same object emits both — the shape renders
its own table, rather than the container rendering one from data it would have
to be handed again. A shape rendered on its own is complete, and the two can
never disagree about who carries the data.

What that buys, and it is the whole point: a screen reader enters a table in
table mode. It moves by row and by column, rereads the column header on demand,
and says "January" again as the reader moves along the row. None of that exists
for a name.

**Two rules decide the rest of it:**

- **`aria-hidden` holds only while nothing inside can take focus.** The pair is
  what axe calls `aria-hidden-focus`, and it is the first thing to check if a
  keyboard cursor over the marks is ever added — which is the open half of this,
  and a different user: someone who sees the screen and has no pointer, and
  today cannot summon the tooltip.
- **A chart of no rows renders no table.** An empty scope on a quiet week is a
  thing a host's data does, and a table of nothing announces a name and then
  leaves a reader in an empty grid. The SVG stays hidden and the chart says
  nothing at all, which is the truth.

**Where it is measured.** axe passes every preview, but axe checks rules — it is
not a screen reader. So `spec/system/chart_spec.rb` reads Chrome's own
accessibility tree and asserts that exactly one node carries the chart's name
and that node is the `table`, with `rowheader "January"` and `cell "186"` in it.
With the name back on the SVG that list reads `["SvgRoot", "table"]`, which is
the double announcement, caught.

**Not `Shadcn::Table`.** That family's classes are all visual — borders,
padding, hover — and every one of them would be dead CSS on an element no one
sees.

## Not reproduced

- **Radar and radial**, which need their own trigonometry rather than a
  cartesian axis, and **stacked lines and areas**: `Plot` computes no cumulative
  points, so `stacked:` is a `Bar` option and is absent from the other two
  rather than being accepted and ignored.
- **Gradient fills.** Upstream's area examples fill from a `<linearGradient>`;
  this fills flat at `fillOpacity={0.4}`. A gradient needs a `<defs>` with an id
  per series, and an id that has to stay unique in a page this gem cannot see is
  a cost the fill does not repay.
- **A y-axis label, a second y-axis, and axis rotation.** The category labels
  skip rather than rotate when they would collide — recharts rotates, which
  needs a measured box.
- **The twelve `[&_.recharts-*]` variants** on the container — seven of them
  named in `allowed_missing`, the other five never looking like classes to the
  tokenizer at all. They select
  recharts' own DOM — its sectors, its cartesian grid, its tooltip cursor — so
  rendering them would compile rules that match nothing in a host's bundle while
  claiming a 1:1 that means nothing. `parity_spec` holds them in
  `allowed_missing` with that reason.
- **Animation, brush, zoom, synchronised charts, logarithmic scales** — four of
  the things recharts has 29,000 lines for.
- **`initialDimension`**, which exists because recharts measures its container
  before it can draw. A `viewBox` needs no measuring, which is also why this
  chart is correct before any JavaScript runs.
