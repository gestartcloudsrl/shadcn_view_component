# Event calendar: the day's agenda in a drawer

**Status:** built (2026-11-16). Agreed in conversation the same day; the
implementation plan has been carried out.

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
  Escape closes, and the focus returns to the day that opened it, which is the
  dialog controller's own focus restore.
- **The second tap does not dispatch `select` again.** The selection did not
  change, so `select` branches on `day === selectedValue` and opens instead.
- **Nothing is drawn under the grid** (agreed, 2026-11-16: "sotto la griglia
  mensile non deve apparire più nulla"). The list moves into the drawer, and
  no summary row or button takes its place. The way in is the selected day
  itself. That costs discoverability for a sighted person who does not know the
  gesture, and the cost is accepted. The selected cell tells assistive
  technology instead (see *Accessibility*).
- **Tapping another day while the drawer is open** is not the path: the
  drawer's overlay covers the grid and its focus trap holds the keyboard.
  Nothing makes the page `inert`, so the builder verifies that a tap through
  the overlay closes the drawer rather than reaching a cell.
- **A row opens the event as now:** its `url:` and `attributes:`. A Sheet
  opened through its own controller stacks over the drawer and closes first on
  Escape. A row's `shadcn--dialog#open` does *not* open a host's Sheet, because
  Stimulus resolves it to the drawer's own controller (observed while building,
  not pinned by a spec): a known gap, in
  [todo.md](../todo.md).

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
the drawer, the list is out of the accessibility tree until opened, and
nothing visible replaces it. What replaces it for assistive technology:

- **The selected cell says it opens something:** `aria-haspopup="dialog"` and
  `aria-expanded` on the selected cell only, and an `aria-describedby` hint
  (*"Premi di nuovo per vedere gli eventi"*). The other cells select, so they
  carry neither *(Claude's call)*.
- **The selection is announced** in a visually hidden `aria-live="polite"`
  region, which is not drawn under the grid: the date, the count and the same
  hint (*"Mercoledì 18 novembre, 3 eventi. Premi di nuovo per vederli."*). It
  is what the agenda's live region announced, minus the list.

This is a real regression in how directly the events can be reached. It is
accepted because the feature is opt-in and the events are one Enter away.

## Left to the builder

- How the controller opens the drawer: an outlet, the drawer's own action, or
  an event, within `.claude/docs/decisions/02-javascript.md`.
- How a link cell tells "selected" on click under `day_url:` with
  `agenda_as: :"turbo-frame"`, where a frame swap does not re-render the grid.
  Measure whether `aria-selected` is stale after the swap before choosing.
- The copy and i18n keys for the hint, the announcement and the drawer's title,
  English in the gem and Italian in the dummy app.
- A Lookbook preview, so the snapshot and axe specs cover the drawer closed
  and open, and system specs for: first tap selects without opening, second
  tap opens, Enter twice opens, Escape returns focus, nothing is
  rendered under the grid, and `day_url:` navigates then opens.
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
