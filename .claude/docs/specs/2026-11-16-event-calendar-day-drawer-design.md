# Event calendar: the day's agenda in a drawer

**Status:** agreed in conversation, 2026-11-16. Feeds an implementation plan;
not itself a plan.

**The question:** on a phone the agenda under the grid pushes the page long
and changes under the thumb on every tap. The person wants the grid alone on
screen, and the day's agenda to appear in a drawer only when they ask for it,
with no widget opening by accident.

## What a person sees

- **The first tap on a day selects it**, as today: the outline moves, `select`
  is dispatched. Nothing opens.
- **A tap on the day that is already selected opens the drawer** with that
  day's agenda: the same title, count, rows and empty line the agenda has now.
  There is no time window: the second tap can come a second or a minute later.
  This was agreed over a timed double tap. A double tap costs the single tap
  its ~300 ms wait, it is the phone's zoom gesture, and it is the *activate*
  gesture under VoiceOver and TalkBack, so a screen-reader user could never
  produce one.
- **From the keyboard**, Enter or Space on the focused day selects it, and a
  second Enter or Space on the selected day opens the drawer. A browser-drawn
  cell is a button, so this falls out of the click. Under `day_url:` the cell
  is an `<a>`, which Space does not activate, so there it is Enter only *(Claude's
  call: making Space open a link would be a key binding of ours on a link)*.
  Escape closes, and the focus returns to whatever opened the drawer: the day
  when it was the day, the summary button when it was the button. That is the
  dialog controller's own focus restore, kept as it is *(Claude's call)*.
- **The second tap does not dispatch `select` again.** The selection did not
  change, so `select` branches on `day === selectedValue` and opens instead.
- **Under the grid there is a summary row instead of the list:** the selected
  date and its count, as one button that opens the drawer (*"Mercoledì 18
  novembre · 3 eventi"*). It is the visible way in for anyone who does not know
  the gesture, and the accessible one (see *Accessibility*). It replaces the
  list (the list moves into the drawer), it is its own
  `data-slot="event-calendar-agenda-summary"`, and with `agenda: false` it is
  absent. Any class of ours it needs gets a `reverse_parity_spec` `ours`
  entry with its reason. It also replaces the
  "small *Open* on the selected cell" floated in the conversation *(Claude's
  call: a button inside the cell would be a second target in a day, which the
  mobile reading's one-target-per-day rule forbids)*.
- **Tapping another day while the drawer is open** is not the path: the
  drawer's overlay covers the grid and its focus trap holds the keyboard.
  Nothing makes the page `inert`, so the builder verifies that a tap through
  the overlay closes the drawer rather than reaching a cell.
- **A row opens the event as now:** its `url:` and `attributes:`. A host that
  opens a Sheet from a row gets the Sheet over the drawer, in the top layer.

## The API

- **`agenda: :drawer`**, beside the existing `true` and `false`. The default
  stays `true`, the agenda under the grid: the gem is published, and changing
  what every host already renders is not this feature's call *(Claude's call)*.
- **The container is the gem's own `Drawer`**, from the bottom, at every
  width. The responsive Drawer-on-phone / Dialog-on-desktop split is not in
  this design.
- `agenda_as:` and `agenda_attributes:` keep applying to the agenda element,
  which now lives inside the drawer's content.

## Readings

- **The events reading (month, drawn in the browser):** as above. The
  controller fills the drawer with `renderAgenda` on select, as it fills the
  list today, and again on open, so a move or a `month-change` while the
  drawer was closed is never shown stale.
- **Server-drawn readings with `day_url:`:** the cell is a link. A click on a
  day that is not selected navigates, as now, and the server renders that day
  selected. A plain click on the selected day does not navigate but opens the
  drawer over the agenda the server already drew. A modified click (cmd,
  ctrl, shift, middle button) is left to the link and navigates.
- **`reading: :daily` with `showing: :agenda` or `:both`:** the agenda is the
  view itself, so `agenda: :drawer` is ignored there and the day keeps its
  list.
- **The workload reading has no agenda**, so nothing changes there.

## Moving an event

The keyboard path picks an event up from an agenda row (`Space`), and today
the grid is visible beside it. In a modal drawer the grid is inert. With
`agenda: :drawer` and `movable:`, **Space on a row closes the drawer and the
pick continues on the grid**, with the focus on the event's day. Escape puts
the event back and returns the focus to that day, without reopening the drawer
*(Claude's call)*. The pick's focus wins over the drawer's focus restore: the
controller focuses the day after the drawer has finished closing. The pointer
grip on the bars is unchanged.

## Accessibility

The agenda is today the only full textual reading of the events reading: the
bars are `aria-hidden` because the agenda says everything they do not. With
the drawer, the list is out of the accessibility tree until opened. What
replaces it at rest is the summary button, which carries the date and the count
and is announced by the existing `aria-live="polite"` when the selection
changes. This is a real regression in how directly the events can be reached,
accepted because the feature is opt-in and the events are one Enter away.

## Left to the builder

- How the controller opens the drawer: an outlet, the drawer's own action, or
  an event, within `.claude/docs/decisions/02-javascript.md`.
- How a link cell tells "selected" on click under `day_url:` with
  `agenda_as: :"turbo-frame"`, where a frame swap does not re-render the grid.
  Measure whether `aria-selected` is stale after the swap before choosing.
- The copy and i18n keys for the summary button and the drawer's title,
  English in the gem and Italian in the dummy app.
- A Lookbook preview, so the snapshot and axe specs cover the drawer closed
  and open, and system specs for: first tap selects without opening, second
  tap opens, Enter twice opens, Escape returns focus, the summary button
  opens, and `day_url:` navigates then opens.
- The feature doc's Options table and a short section.
- Checking, rather than assuming, that a Sheet opened from a row stacks above
  the drawer in the dialog controller's layers, and the `Drawer`'s direction
  default for a bottom drawer.

## Not in this design

- A timed double tap.
- Opening the drawer on the first tap.
- A Dialog or side Sheet on desktop instead of the bottom Drawer.
- Quick actions inside the drawer (*+ New intervention*). The `new_url:` idea
  from the critique is separate.
