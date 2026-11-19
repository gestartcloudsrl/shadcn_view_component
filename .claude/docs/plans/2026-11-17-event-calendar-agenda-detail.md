# Event calendar agenda detail — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** with `agenda: :drawer, agenda_detail: { frame:, attributes: }`, a
row with a `url:` shows the event's detail inside the drawer, in a
`<turbo-frame>` the gem draws, with a «Back to the day» button, Escape going
back before it closes.

**Architecture:** the dialog controller gains a cancelable
`shadcn--dialog:escape-key-down`, dispatched on its root before an Escape
hides it. The calendar draws a hidden detail pane (back button + frame)
beside the agenda inside the drawer's content, gives link rows a default
`data-turbo-frame` and a click action, and its controller swaps list ↔ pane.
Turbo does the loading; the gem never waits for it.

**Tech Stack:** Ruby / ViewComponent, Stimulus, RSpec + Capybara + headless
Chrome, Turbo in the dummy app.

**Spec:** [`.claude/docs/specs/2026-11-17-event-calendar-agenda-detail-design.md`](../specs/2026-11-17-event-calendar-agenda-detail-design.md).
Read it first.

## Global Constraints

- Without `agenda_detail:` (or without `frame:`, or without `agenda: :drawer`)
  nothing is rendered or wired differently: **every existing golden stays
  byte-identical**.
- Attribute precedence: `data-slot` < component defaults < caller. A row's
  event `attributes:` beat the gem's default `data-turbo-frame`; `class` and
  `data-action` join. The frame's `id` is always `frame:`.
- Never split a class string across a `\` line continuation.
- Any class no vendored TSX contains needs a `reverse_parity_spec` `ours`
  entry with its reason.
- Code identifiers and comments in English. Commit messages in English, each
  ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never
  push.
- i18n: `shadcn_view_component.event_calendar.agenda_back` — en
  `"Back to the day"` in `config/locales/en.yml`, it `"Torna al giorno"` in
  `test/dummy/config/locales/it.yml`.

## Review Focus

1. A dialog nested inside the detail (the dummy's AlertDialog) dispatches its
   own `escape-key-down`, which bubbles to the drawer: the calendar must act
   only when `event.target` is its drawer root.
2. A row with `data: { turbo: false }`, or naming another frame, must not
   switch to the pane — it navigates as now.
3. Reopening after close, or after selecting another day, shows the list and
   an empty frame — never the previous detail.
4. Server-drawn rows (`day_url:`) and browser-drawn rows (cloned from the link
   prototype by `link()`) both carry the default and the action.
5. The pane scrolls inside the panel from the right and from the bottom.

---

### Task 1: the dialog's cancelable Escape

**Files:**
- Modify: `app/javascript/shadcn/controllers/dialog_controller.js` (the
  `onDismiss` passed to `pushLayer`)
- Test: `spec/system/dialog_spec.rb`
- Modify: `.claude/docs/features/` — the dialog's feature doc, one paragraph

**Interfaces:**
- Produces: on Escape, before `hide()`, the dialog dispatches
  `this.dispatch("escape-key-down", { cancelable: true })` on its own element
  (event name `shadcn--dialog:escape-key-down`); `defaultPrevented` keeps it
  open. Pointer dismissal is unchanged. Only the top layer receives Escape
  (already true of `dismiss.js`).

- [ ] **Step 1: failing system specs** in `dialog_spec.rb`, on an existing
  dialog preview: (a) a listener calling `preventDefault()` on
  `shadcn--dialog:escape-key-down` keeps the dialog open after Escape; (b)
  without it, Escape closes as before and the event was dispatched once; (c)
  with a layer stacked on top (pick an existing stacking preview, or open a
  second dialog by script), Escape dispatches only on the top one.
- [ ] **Step 2:** run them, see (a) and (c) fail.
- [ ] **Step 3:** implement. A one-line comment naming Radix's
  `onEscapeKeyDown` on `Dialog.Content` as what it ports (Radix's
  `dialog.tsx` is not vendored; `DismissableLayer`'s prop is, in
  `vendor/radix/ui/hover-card.tsx`).
- [ ] **Step 4:** `bundle exec rspec spec/system/dialog_spec.rb spec/system/drawer_spec.rb spec/system/sheet_spec.rb` green (whichever of those exist), `bin/eslint` clean.
- [ ] **Step 5:** doc paragraph, commit.

### Task 2: the detail pane's markup

**Files:**
- Modify: `app/components/shadcn/event_calendar/component.rb`
- Modify: `app/javascript/shadcn/controllers/event_calendar_controller.js`
  (declarations only: targets `agendaDetail`, `agendaFrame`, `agendaBack`;
  value `detailFrame: String`; empty action methods `openDetail`,
  `showList`, `detailEscape` — so `stimulus_contract_spec` stays green)
- Modify: `config/locales/en.yml`, `test/dummy/config/locales/it.yml`
- Create: `app/components/shadcn/event_calendar/previews/agenda_drawer_detail.html.erb`
  and its method in `preview.rb`
- Test: `spec/components/shadcn/event_calendar_spec.rb`, goldens,
  `spec/reverse_parity_spec.rb`

**Interfaces:**
- Produces (Ruby): `agenda_detail:` kwarg (default `nil`), reader
  `agenda_detail`; private `agenda_detail? = agenda_drawer? &&
  agenda_detail&.dig(:frame).present?` (accept string keys too);
  `detail_frame` → the id.
- Produces (markup), all only when `agenda_detail?`:
  - root: `data-shadcn--event-calendar-detail-frame-value="<frame>"`.
  - drawer root (the `agendaDrawer` target) gains
    `data-action="shadcn--dialog:escape-key-down->shadcn--event-calendar#detailEscape"`.
  - inside the drawer content, after the agenda:
    `div[data-slot=event-calendar-agenda-detail][hidden][data-shadcn--event-calendar-target=agendaDetail]`
    with the agenda's drawer column/scroll classes (`AGENDA_DRAWER_CLASS`), holding:
    1. a `Button::Component` `variant: :ghost, size: :sm`, `data-slot`
       its own, target `agendaBack`, `data-action="click->shadcn--event-calendar#showList"`,
       lucide `chevron-left` icon + `shadcn_t("event_calendar.agenda_back")`;
    2. `<turbo-frame id="<frame>" data-shadcn--event-calendar-target="agendaFrame" …attributes>`
       — `attributes:` merged with `merge_attributes`, then `id` forced.
  - every link row (`agenda_link`, which also produces the prototype the
    browser clones): defaults `"data-turbo-frame" => frame` and
    `"data-action" => "click->shadcn--event-calendar#openDetail"`, *under* the
    event's attributes (host wins `data-turbo-frame`; `data-action` joins).
- Preview `agenda_drawer_detail(direction: "right", day_links: false)`:
  `render_with_template(locals:)`; template renders the month of
  2026-08 selected 2026-08-05, `agenda: :drawer`, `drawer_direction:`,
  `agenda_detail: { frame: "agenda-detail", attributes: { target: "_top" } }`,
  `day_url: ->(d) { "/calendar/days/#{d.iso8601}" }` only when `day_links`;
  events on the 5th: two with `url: "/calendar/events/1"` / `"/2"`, one with
  `url: "/turbo-probe/one", attributes: { data: { turbo: false } }`, and enough
  url-less rows (≥16) on 2026-08-06 to overflow the panel for the scroll spec.

- [ ] **Step 1: failing component specs** (new `describe "agenda_detail:"`):
  pane hidden and after the agenda inside `[data-slot=drawer-content]`; frame
  id `agenda-detail`, `target="_top"`, a host `id:` in `attributes:` ignored;
  back button text "Back to the day" and its action; link rows carry
  `data-turbo-frame="agenda-detail"` and the `openDetail` action; a row with
  `attributes: { data: { turbo_frame: "other" } }` keeps `other`; the root
  value and the drawer's escape action; **none** of it without the option,
  without `frame:`, or with `agenda: true`.
- [ ] **Step 2:** run, see them fail.
- [ ] **Step 3:** implement; JS declarations as listed.
- [ ] **Step 4:** `SNAPSHOTS=overwrite bundle exec rspec spec/snapshot_spec.rb -e agenda_drawer_detail`,
  then `bundle exec rspec spec/snapshot_spec.rb spec/components spec/reverse_parity_spec.rb spec/parity_spec.rb spec/stimulus_contract_spec.rb`
  green with `git diff --stat spec/fixtures` showing only the new golden.
  `bin/rubocop` clean.
- [ ] **Step 5:** commit.

### Task 3: list ↔ detail in the controller, and the dummy app's answer

**Files:**
- Modify: `app/javascript/shadcn/controllers/event_calendar_controller.js`
- Modify: `test/dummy/app/views/calendar/event.html.erb` (and the controller
  if needed)
- Test: `spec/system/event_calendar_spec.rb`

**Interfaces:**
- Consumes: Task 1's event; Task 2's targets, value and actions.
- `openDetail(event)`: return unless `detailFrameValue` and the pane exist;
  return for a modified or non-primary click; return if
  `link.closest("[data-turbo='false']")` or `link.dataset.turboFrame !==
  detailFrameValue`. Otherwise: remember the link as the opener, empty the
  frame (`removeAttribute("src")`, `replaceChildren()`), hide the agenda,
  show the pane, focus `agendaBack`. Never `preventDefault` — Turbo loads.
- `showList()`: hide the pane, empty the frame, show the agenda, focus the
  opener if it is still connected (else nothing). Called by the back button.
- `detailEscape(event)`: only when `event.target === agendaDrawerTarget` and
  the pane is shown: `event.preventDefault()`, `showList()`.
- Reset: the drawer's `shadcn--dialog:close` (the listener the controller
  already has for `aria-expanded`) and `select`/`openDay` call a reset that
  hides the pane, empties the frame and shows the agenda **without moving
  focus**.
- Dummy: `event.html.erb` answers with
  `<turbo-frame id="<%= request.headers["Turbo-Frame"] || "event" %>">` so the
  existing Sheet specs (frame `event`) keep passing, and inside it adds: a link
  "Client page" to `/turbo-probe/one` with no data attributes, and an
  `AlertDialog` «Delete» (trigger + content + cancel) built from the gem's
  components.

- [ ] **Step 1: failing system specs** (`describe "an event's detail in the drawer"`,
  on `agenda_drawer_detail`): tap the 5th twice, click "Boiler…" row →
  pane visible, list hidden, frame shows "Event 1", focus on "Back to the day";
  back → list visible, focus on that row; open detail, Escape → list, Escape →
  drawer closed, focus on the 5th; reopen after close → list, frame empty;
  the `turbo: false` row → page lands on `/turbo-probe/one`; "Client page" in
  the detail → whole page navigates to `/turbo-probe/one` (current_path, and
  the calendar gone); «Delete» in the detail → alert dialog above the drawer,
  Escape closes it with the drawer still on the detail, next Escape → list;
  with `?day_links=true` a row opens the detail too; on the 6th the pane's
  last row/element is reachable after scrolling (`direction=right` and
  `direction=bottom`) — use the measuring approach of the existing "scrolls a
  full day inside the panel" spec.
- [ ] **Step 2:** run, see them fail.
- [ ] **Step 3:** implement.
- [ ] **Step 4:** `bundle exec rspec spec/system/event_calendar_spec.rb` and the
  Sheet-over-drawer specs green; `bin/eslint`, `bin/rubocop` clean.
- [ ] **Step 5:** commit.

### Task 4: docs

**Files:** `.claude/docs/features/event-calendar.md` (Options row for
`agenda_detail:`, a section "An event's detail in the drawer": the option, how
a row chooses, `target: "_top"` and why, Escape/focus/name, reset, what the
specs cover and do not), the design's status line set to built,
`.claude/docs/todo.md` — narrow the "Sheet from a row inside the drawer" entry
to say `agenda_detail:` is the path for a detail. Every sentence stays inside
what the code and specs establish.

- [ ] **Step 1:** write. **Step 2:** `bundle exec rake` green. **Step 3:** commit.
