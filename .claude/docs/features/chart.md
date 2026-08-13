# Chart

*Frame ported 1:1; the drawing is **ours**. First shape: the pie.*

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

**The pie.** An arc is trigonometry and an SVG path, which is why it is the
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

**A colour is filtered before it reaches the `<style>`.** Upstream writes the
config's colours through `dangerouslySetInnerHTML`, where a `}` would close the
rule and everything after it would be the caller's own CSS running in the host's
page. A library that runs inside an application it cannot see does not get to be
exposed to that, so a colour has to look like one.

## Accessibility, decided rather than patched

The SVG is one `role="img"` with a name that carries the whole chart: *"Visitors
by browser — Chrome: 275, Safari: 200, …"*. Everything inside a `role="img"` is
presentational, so the name has to be the data or the data is gone.

The first version gave each slice its own `aria-label` and a `tabindex`, and axe
was right to fail it: `aria-label` on a `<path>` with no role is prohibited. The
slices are decoration now, and the tooltip is a pointer affordance rather than
the only way to the numbers.

**What that costs:** a keyboard user gets the name, not the tooltip. Upstream's
`accessibilityLayer` makes recharts' chart arrow-navigable, and this does not.

## Not reproduced

- **Every other shape**: bars, lines, areas, radar, radial. Axes, grids, ticks
  and legends-inside-the-SVG come with them, and none of it is in `chart.tsx`.
- **The thirteen `[&_.recharts-*]` variants** on the container. They select
  recharts' own DOM — its sectors, its cartesian grid, its tooltip cursor — so
  rendering them would compile rules that match nothing in a host's bundle while
  claiming a 1:1 that means nothing. `parity_spec` holds them in
  `allowed_missing` with that reason.
- **Animation, brush, zoom, synchronised charts, logarithmic scales** — four of
  the things recharts has 29,000 lines for.
- **`initialDimension`**, which exists because recharts measures its container
  before it can draw. A `viewBox` needs no measuring, which is also why this
  chart is correct before any JavaScript runs.
