# Calendar

*Adapted: 1:1 in markup, rebuilt on `Date` and `I18n` instead of
`react-day-picker`.*

`calendar.tsx` is 220 lines that hand 30 class names to `react-day-picker` and
let it render. So unlike `sonner.tsx`, **every class is a literal in the file
this repo already vendors** — what had to be read from the package is the markup
those classes land on, and it was read twice: from the package's own `dist`, and
from upstream's rendered example. Both say

```
table[role=grid] → thead[aria-hidden] → th[scope=col]
                 → tbody → tr → td[role=gridcell] → button
```

## Why there is no dependency

Measured before deciding, at the version whose API `calendar.tsx` uses (9.14.0):

| | lines of compiled ESM |
|---|---|
| the package | 9,744 |
| of which locale data | 3,479 |
| of which Ethiopic, Hebrew, Hijri, Persian, Jalali, Buddhist calendars | 2,046 |
| of which `classes/DateLib.js`, wrapping `date-fns` | 576 |

Plus `date-fns` (10.4 MB unpacked) and `@date-fns/tz`.

Almost none of it is a component. It is date arithmetic and locale data, and a
Rails app has both. `Calendar::Month` is the grid — a plain object, so the
arithmetic is asserted directly instead of through a browser.

And this is the first family here that **renders correctly with no JavaScript at
all**: a month is a table, and the server can draw it.

## The grid exists twice, and that is the risk

The server draws the month it was given; the controller draws every month
reached from the nav, because a round trip per month is a route this gem cannot
assume a host will provide. Two rules keep the copies from drifting:

- **No text in JavaScript.** Month names, weekday names, the date format and
  the label templates cross as values. `Intl` would answer to the *browser's*
  locale, so an app serving Italian to a reader whose browser is English would
  spell the month one way before the click and another after it.
- **No class in JavaScript.** The modifier classes cross as values too: Tailwind
  scans source text and never reads the controller, and `parity_spec` reads the
  Ruby. Even the structure is cloned from what the server rendered.

What actually keeps them honest is one example: `spec/system/calendar_spec.rb`
navigates to September in the browser and compares every cell — state, classes
and labels — against the September the server renders at `?month=2026-09-01`.

**Today comes from the server too.** `Time.zone` and a laptop's clock disagree
by a day for a few hours out of every twenty-four, and the server has already
marked a cell `data-today`. Found by a preset landing on the wrong day.

## What is upstream's

- **The three selection modes**, read from `selection/useSingle.js`,
  `selection/useMulti.js` and `utils/addToRange.js`. Worth knowing about the
  third: a finished range does **not** start over on the next click — a day
  after the start moves the *end*, a day before it moves the *start*, and
  clicking one of the ends collapses the range onto it.
- **Single clears when the selected day is clicked again**, unless `required:`.
- **The keyboard**, from `DayPicker.js:176-190`: a day, a week, the ends of a
  week, and a month or a year on the Page keys. `Home` and `End` land on the
  week's ends *as the application defines them* — `Date.beginning_of_week`,
  where upstream takes the week start from the locale.
- **`captionLayout: :dropdown`**, two native `<select>`s laid invisible over the
  label — the same technique as the one-time-code field, and upstream's here.
- **`numberOfMonths`**, one nav over as many grids as asked for.
- **The `<td>` for a week number**, which is `calendar.tsx`'s own override of a
  `<th>` the package renders (calendar.tsx:167-175).

## What is this port's

- **`preset`.** Upstream's own Presets example holds five shortcuts in React
  state; a Rails app has no state to hold them in, so the offset in days rides
  on the button and the controller does arithmetic it is already doing. A host
  writes no JavaScript.
- **The form inputs.** `name:` renders hidden inputs and the controller rewrites
  them:

  | `mode:` | `name: "trip[on]"` becomes |
  |---|---|
  | `:single` | `trip[on]` |
  | `:multiple` | `trip[on][]`, one per day |
  | `:range` | `trip[on][from]` and `trip[on][to]` |

  A range can take two names of its own instead — `f.shadcn_calendar :starts_on,
  mode: :range, to: :ends_on` — because two dates are usually two columns, and
  then `permit(:starts_on, :ends_on)` is all a controller needs.

  An empty value is still posted when nothing is chosen, for the reason Rails'
  own hidden checkbox field exists: a parameter that vanishes leaves the old
  value in the record.
- **`shadcn--calendar:select`**, carrying the selection and the day that changed
  it. Upstream takes an `onSelect` callback, and a callback has no markup.
- **Block content**, rendered after the months where upstream's `footer` prop
  renders — which is what lets a preset button's `data-action` reach the
  controller.

## A time beside the date

Neither half of upstream's Date-and-Time example is a component here — a time is
an `<input type="time">` and a list of times is a `<select>` — but which one to
reach for was measured rather than assumed, and it is the sort of thing a host
asks:

**`step` is in seconds**, so `step: 900` is a quarter of an hour. Measured in
Chrome: the field's own arrows then move 09:00 → 09:15 → 09:30, and a typed
09:07 is refused at submit with the browser's message naming the two nearest
valid values. What it does **not** do is turn the field into a list — the
segments still accept any digits, and the complaint arrives afterwards.

So where only a quarter-hour will do, the control is a `<select>` and not a
stepped time field: a list can only be chosen from, and its options are built
in Ruby where the opening hours already live. `time_slots` is that preview, and
the two of them together are what a booking form posts — `booking[on]` from the
calendar and `booking[at]` from the select.

## Not reproduced

- **The other calendar systems** — Ethiopic, Hebrew, Hijri, Persian, Jalali,
  Buddhist. A third of the package, and none of it is `calendar.tsx`.
- **A callable `disabled:` beyond the rendered month.** `disabled:` takes
  anything answering `===`, and a `Date` or a `Range` crosses to the browser as
  itself. A lambda cannot: it decided the month the server rendered and says
  nothing about a month reached from the nav. Use dates or ranges wherever
  navigation matters.
- **Locale week numbers.** `Month#number_of` is ISO-8601 — `Date#cweek` — where
  upstream's follows the locale, and the US counts from a different week.
- **`modifiers` / `modifiersClassNames`.** Upstream's Booked example strikes
  through the taken days with them; here that is a class on the root reaching
  its own cells, which is what the preview shows.
- **`min` / `max` on a range**, `excludeDisabled`, `timeZone`, animation, and
  the `broadcastCalendar` and `ISOWeek` variants.
- **The `rdp-*` class names**, except the two `calendar.tsx` names itself in an
  RTL rule (`rdp-button_previous` and `rdp-button_next`). The rest come from
  `getDefaultClassNames()` — a function call rather than a string in the
  vendored source — and nothing here styles them.

## What no spec here proves

`parity_spec` compares token *sets per family*, so a class defined in a constant
and used nowhere still counts as ported: the mutation that removes
`RTL_CHEVRONS` from the style block survives, and only emptying the constant
fails. What ties a class to an element is `snapshot_spec`.
