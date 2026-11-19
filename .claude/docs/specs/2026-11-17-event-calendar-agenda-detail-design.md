# Event calendar: an event's detail inside the agenda drawer

**Status:** built (2026-11-17; commits 145c574, c267558, e9cb586, 197fde6); agreed, from a request written by Gestart; the three
calls below were approved as proposed, and `attributes:` was added.

**The question:** with `agenda: :drawer`, a row of the day's agenda opens the
event's detail in a Sheet of the host's, on top of the drawer. Gestart wants
the detail to open *inside* the same drawer, in place of the list, with a way
back to the day.

## What a person sees

- **A tap on a row with a `url:` shows the detail in the drawer.** The list is
  hidden and a pane takes its place: a «Torna al giorno» button at its top,
  then a `<turbo-frame>` that Turbo fills with what the row's URL answers.
  Without Turbo on the page the row is a plain link and the browser goes to
  the URL; nothing in the gem waits for a load.
- **The back button returns to the day's list** with no request (the list is
  already in the page) and puts the focus back on the row that opened the
  detail.
- **Escape in the detail goes back to the list; Escape in the list closes the
  drawer** and returns the focus to the day, as now.
- **The detail scrolls inside the panel**, from the right and from the bottom,
  the way the list does since 0564666.
- **Closing the drawer, or selecting another day, resets it to the list.** The
  next opening never shows the last detail. The frame is emptied, so a stale
  detail cannot flash before Turbo answers.
- **A layer opened from inside the detail** (Gestart's «Elimina» confirmation)
  stacks above the drawer, and Escape closes that layer first.

## The API

- **`agenda_detail: { frame: "agenda-detail" }`**, as Gestart proposed. Only
  with `agenda: :drawer`; anywhere else, or without `frame:`, nothing changes.
  A Hash rather than a bare id, so a later key does not change its shape
  *(Gestart's shape kept)*.
- **`agenda_detail: { frame: "agenda-detail", attributes: { target: "_top" } }`**
  (agreed, 2026-11-17). `attributes:` is merged onto the `<turbo-frame>` the
  gem draws, with the gem's precedence (the host's keys win, `class` joins),
  except `id`, which is always `frame:`. It exists for `target: "_top"`: Turbo
  reads `target` from the frame in the page, not from the response, so a link
  inside the detail with no `data-turbo-frame` of its own (Gestart's client
  and site links) navigates the whole page only if the gem's frame carries it.
- **The gem renders the frame**: `<turbo-frame id="agenda-detail">` inside the
  drawer's content, beside the agenda, never inside it. A day swap under
  `agenda_as: :"turbo-frame"` therefore never replaces it. The gem names
  `turbo-frame` here only because the host asked for one by passing `frame:`,
  as it does for `agenda_as:`.
- **The i18n key `event_calendar.agenda_back`**: English «Back to the day» in
  the gem, Italian «Torna al giorno» in the dummy app.

## How a row chooses

- **By default a row with a `url:` targets the frame**: the gem puts
  `data-turbo-frame="agenda-detail"` on it as a *default*, below the event's
  `attributes:` in precedence, on both the server-drawn row (`agenda_link`)
  and the browser-drawn one (`link` in the controller, which clones the same
  prototype).
- **The row's own attributes decide otherwise.** The controller shows the
  detail only on a plain primary click on a row whose resolved
  `data-turbo-frame` is the configured frame and that has no
  `data-turbo="false"` on itself or an ancestor. A row that names another frame
  goes there, and a row with `data: { turbo: false }` (Gestart's reminders)
  opens its page as now. A modified click (cmd, ctrl, shift, middle button) is
  left to the link.
- **Rows without a `url:`** are not links and open nothing, as now.

## Escape, focus and the name

- **Escape needs a hook in the dialog controller.** Today the dismiss stack
  calls the drawer's `onDismiss`, which hides it, and nothing can step in. The
  dialog controller will dispatch a cancelable `shadcn--dialog:escape-key-down`
  on its root before hiding on Escape, and only the dialog at the top of the
  stack dispatches it (agreed, 2026-11-17). It is a port of Radix's
  `onEscapeKeyDown` on `Dialog.Content`, whose `preventDefault()` keeps the
  dialog open. That prop appears in the vendored Radix sources through
  `DismissableLayer` (`hover-card.tsx`, `menu.tsx`, `select.tsx`); Radix's
  `dialog.tsx` is not vendored here. The calendar listens on its drawer and,
  while the detail is shown, cancels it and goes back to the list. Only the
  topmost layer receives Escape, so a confirmation opened from the detail
  closes first. The calendar checks `event.target` is its own drawer, because
  a dialog nested in the detail dispatches the same event and it bubbles.
- **Focus when the detail opens goes to the back button**, because the row
  that had it is now hidden. The button is the one element the gem owns in the
  pane; the frame's content is the host's and may not have arrived yet
  *(Claude's call)*.
- **The drawer stays named by the day** (`aria-labelledby` on the agenda's
  title, which is hidden but still names it). The detail is a page within that
  day's drawer, and the host's frame content has no heading the gem can rely
  on *(Claude's call, the open question Gestart left to us)*.

## Left to the builder

- The pane's markup and classes: the back button is the gem's `Button`
  (`variant: :ghost`, `size: :sm`) with lucide `chevron-left`, and the pane
  takes the agenda's column and scroll classes.
- Where the state lives in the controller (`showDetail(row)`, `showList()`),
  and calling `showList()` from the drawer's `shadcn--dialog:close` and from
  `select`/`openDay`.
- The dummy app: `calendar#event` answering with the `Turbo-Frame` request
  header's id, as Gestart's views do, an `AlertDialog` «Delete» inside it for
  the stacking check, and a plain link to a page of its own for the `_top`
  check.
- A template preview with the option, under the snapshot and axe specs, and
  system specs for: a row opens the detail in the drawer; back returns to the
  list with the focus on the row; a link inside the detail, with no
  `data-turbo-frame` of its own, navigates the whole page under
  `attributes: { target: "_top" }`; two Escapes (detail, then list) close it with
  the focus on the day; a reopening shows the list; a `data: { turbo: false }`
  row navigates; a confirmation from the detail stacks and closes first on
  Escape; the detail scrolls from the right and from the bottom.
- The feature doc's Options table and a short section; a line in the dialog
  docs for the new event.

## Not in this design

- A detail without Turbo (a fetch of the gem's own).
- Naming the drawer by the detail's heading.
- The detail in the readings without a drawer, where the host's Sheet stays the
  path.
