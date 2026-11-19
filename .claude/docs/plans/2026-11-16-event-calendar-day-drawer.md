# Event calendar day drawer — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `agenda: :drawer` moves the day's agenda into a bottom `Drawer`. The
drawer opens on a second tap (or Enter) on the day that is already selected,
and nothing is drawn under the month grid.

**Architecture:** the server wraps the existing `agenda` element in a
`Drawer::Component` with no trigger. It adds an sr-only hint and an sr-only
selection live region, and marks the selected cell with
`aria-haspopup="dialog"`. The calendar controller reaches the drawer the way it
already reaches the preferences dialog: a target plus
`application.getControllerForElementAndIdentifier(target, "shadcn--dialog")`.
`select` branches on `day === selectedValue`, and link cells get an action of
their own.

**Tech Stack:** Ruby / ViewComponent, Stimulus, RSpec + Capybara + headless
Chrome.

**Spec:** [`.claude/docs/specs/2026-11-16-event-calendar-day-drawer-design.md`](../specs/2026-11-16-event-calendar-day-drawer-design.md).
Read it first.

## Global Constraints

- `agenda:` keeps `true` as its default; `:drawer` (or `"drawer"` from params)
  is opt-in. `false` still draws no agenda.
- With `:drawer`, **nothing** is rendered under the grid outside the drawer:
  no list, no summary, no button.
- The second tap on the selected day **does not dispatch `select`** again.
- `Daily::Component` ignores `:drawer` (its agenda is the view).
- Never split a class string across a `\` line continuation.
- Attribute precedence: `data-slot` < component defaults < caller.
- A value an optional feature needs is not written when the feature is off:
  the existing goldens must not move.
- Any class no vendored TSX contains needs a `reverse_parity_spec` `ours`
  entry with its reason. Regenerate goldens first
  (`SNAPSHOTS=overwrite bundle exec rspec spec/snapshot_spec.rb`).
- Ids follow `shadcn-<part>-<eight hex>`, one hex per instance (see
  `PreferencesDialog#preference_id`).
- Code and comments in English; Italian strings only in
  `test/dummy/config/locales/it.yml`.
- Full check: `bundle exec rake`, `bin/rubocop`, `bin/eslint`.

**Ruling on a spec gap:** the spec says "the workload reading has no agenda".
Under `day_url:` it does (`Component#agenda?` is
`@agenda && (client_drawn? || day_url.present?)`). So `:drawer` applies
wherever `agenda?` is true, except in `Daily`. If that is wrong, the cost is one
override returning `false`.

## Review Focus

1. **Selected day changes by navigating the month** (‹ ›, or an arrow off the
   edge). A second tap on the new selection opens the drawer showing *that* day.
   Covered in Task 2.
2. **A tap on the overlay while the drawer is open** closes the drawer and does
   not select the cell underneath. Covered in Task 2.
3. **An empty day**: the drawer opens with *"Nothing scheduled."*. Covered in
   Task 2.
4. **A cmd/ctrl/shift-click or middle click on the selected link cell**
   navigates rather than opening. Covered in Task 3.
5. **Two calendars on one page**: hint and title ids are distinct, so
   `aria-describedby` and `aria-labelledby` never cross. Covered in Task 1.

---

### Task 1: the drawer's markup

**Files:**
- Modify: `app/components/shadcn/event_calendar/component.rb`: `initialize`
  (normalise `agenda:`), `call`, `agenda`, `day_cell`, plus new private
  methods `agenda_drawer?`, `agenda_drawer`, `drawer_hint`,
  `selection_announcer`, `drawer_id(part)`.
- Modify: `app/components/shadcn/event_calendar/daily/component.rb`:
  `agenda_drawer? = false`.
- Modify: `config/locales/en.yml` (`event_calendar.drawer_hint`) and
  `test/dummy/config/locales/it.yml`.
- Modify: `app/components/shadcn/event_calendar/preview.rb`: an `agenda`
  param on `density` (`select [below, drawer]`), plus a new template preview
  `agenda_drawer` (`previews/agenda_drawer.html.erb`): August 2026, `selected:`
  the 20th, `agenda: :drawer`, at a 390px frame like `phone`.
- Test: `spec/components/shadcn/event_calendar_spec.rb` (a `#agenda` /
  `"as a drawer"` context), snapshot goldens, `reverse_parity_spec.rb`.

**Interfaces:**
- Produces, in the markup:
  - the Drawer root carrying `data-shadcn--event-calendar-target="agendaDrawer"`;
  - the agenda title with `id="shadcn-event-calendar-<hex>-agenda-title"`, and
    the drawer content's `aria-labelledby` pointing at it;
  - `[data-slot=event-calendar-drawer-hint]`, an sr-only element with
    `id="shadcn-event-calendar-<hex>-drawer-hint"`;
  - `[data-slot=event-calendar-selection]`, sr-only, `role="status"`,
    `aria-live="polite"`, empty, with
    `data-shadcn--event-calendar-target="selectionAnnouncer"`;
  - on the selected cell only: `aria-haspopup="dialog"`,
    `aria-expanded="false"`, `aria-describedby=<hint id>`;
  - on link cells (`day_url:`), when the drawer is on:
    `data-action="click->shadcn--event-calendar#openDay"`;
  - on the root, `data-shadcn--event-calendar-drawer-value="true"`, and only
    when the drawer is on.
- Copy: en `drawer_hint: "Press again to see the events."`, it
  `"Premi di nuovo per vedere gli eventi."`.

- [ ] **Step 1: Write the failing component specs**

```ruby
context "with agenda: :drawer" do
  subject(:page) { render_inline(described_class.new(month: Date.new(2026, 8, 1), selected: Date.new(2026, 8, 20), events:, agenda: :drawer)) }

  it "draws the agenda inside a drawer" do
    expect(page).to have_css("[data-slot=drawer-content] [data-slot=event-calendar-agenda]")
  end

  it "draws nothing between the grid and the drawer" do
    expect(page).to have_no_css("[data-slot=event-calendar] > [data-slot=event-calendar-agenda]")
  end

  it "names the drawer by the agenda's title" do
    title = page.at_css("[data-slot=event-calendar-agenda-title]")
    expect(page.at_css("[data-slot=drawer-content]")["aria-labelledby"]).to eq(title["id"])
  end

  it "marks only the selected cell as opening a dialog" do
    expect(page).to have_css("[data-day='2026-08-20'][aria-haspopup=dialog][aria-expanded=false]")
    expect(page.css("[aria-haspopup=dialog][data-slot=event-calendar-day]").size).to eq(1)
  end

  it "describes the selected cell with the hint" do
    hint = page.at_css("[data-slot=event-calendar-drawer-hint]")
    expect(hint.text).to eq("Press again to see the events.")
    expect(page.at_css("[data-day='2026-08-20']")["aria-describedby"]).to eq(hint["id"])
  end

  it "carries a polite live region for the selection" do
    expect(page).to have_css("[data-slot=event-calendar-selection][role=status][aria-live=polite]", text: "")
  end

  it "gives two calendars distinct ids" do
    ids = 2.times.map { render_inline(described_class.new(month: Date.new(2026, 8, 1), agenda: :drawer)).at_css("[data-slot=event-calendar-drawer-hint]")["id"] }
    expect(ids.uniq.size).to eq(2)
  end

  it "accepts the string from params" # agenda: "drawer" renders the drawer
  it "wires link cells to openDay"     # with day_url:, every <a> cell has click->shadcn--event-calendar#openDay
end

it "renders no drawer, hint or haspopup by default" # agenda: true — the goldens enforce the rest
it "ignores :drawer on the day reading"             # reading: :daily, showing: :both, agenda: :drawer → no drawer-content
```

- [ ] **Step 2: Run them and see them fail**

Run: `bundle exec rspec spec/components/shadcn/event_calendar_spec.rb -e "agenda: :drawer"`
Expected: FAIL, with no `drawer-content` found.

- [ ] **Step 3: Implement**

`agenda_drawer? = @agenda == :drawer && agenda?`. Normalise `"drawer"` to
`:drawer` in `initialize`.

In `call`, the agenda slot becomes
`(agenda_drawer? ? agenda_drawer : agenda) if agenda?`. The hint and the
selection region go after it, only when `agenda_drawer?`.

`agenda_drawer` renders `Drawer::Component.new("data-shadcn--event-calendar-target": "agendaDrawer")`
with `with_dialog_content` holding `agenda`, which keeps `agenda_as:` and
`agenda_attributes:`. Under the drawer, the agenda drops its `aria-live`,
because the selection region announces instead.

Before adding the drawer's own markup, check how `Preferences.new(agenda: @agenda)`
reads `@agenda`. It must stay truthy-equivalent for `:drawer`.

- [ ] **Step 4: Run the specs, then regenerate and check the goldens**

Run: `bundle exec rspec spec/components/shadcn/event_calendar_spec.rb`, then
`SNAPSHOTS=overwrite bundle exec rspec spec/snapshot_spec.rb` and `git status spec/`.
Expected: PASS. The only new golden is `agenda_drawer`, and no existing one
changes. Then `bundle exec rspec spec/reverse_parity_spec.rb spec/parity_spec.rb`
and add `ours` entries if a class of ours appears.

- [ ] **Step 5: Commit** — `Draw the day's agenda inside a drawer when asked`

---

### Task 2: the second tap opens it (browser-drawn cells)

**Files:**
- Modify: `app/javascript/shadcn/controllers/event_calendar_controller.js`:
  targets `agendaDrawer`, `selectionAnnouncer`; value `drawer: Boolean`;
  `select`, `markSelection`, new `openDay(event)`, getter `agendaDrawer`
  (the `preferencesDialog` getter's shape), `announceSelection()`, and a
  listener for `shadcn--dialog:open` / `shadcn--dialog:close` on the drawer
  that keeps `aria-expanded` on the selected cell in step.
- Test: `spec/system/event_calendar_spec.rb`, a `describe "the agenda as a drawer"`
  block against the `agenda_drawer` preview.

**Interfaces:**
- Consumes: Task 1's targets, value, slots and ids.
- Produces: `openDay(event)`, which Task 3 wires to link cells. On a browser
  cell it is called from `select`. It calls `renderAgenda()` before
  `agendaDrawer.open()`.

- [ ] **Step 1: Write the failing system specs**

Each example states what a person does and what they see:

- `"the first tap selects and opens nothing"`: click the 21st. It gets
  `aria-selected`, `select` is dispatched once, and no `[role=dialog]` is
  visible.
- `"a tap on the selected day opens the drawer with that day"`: click the 21st
  twice. The dialog named by the 21st's date is visible, `select` was
  dispatched once in all, and the cell has `aria-expanded="true"`.
- `"Enter twice opens it, and Escape returns the focus to the day"`.
- `"the selection is announced with the hint"`: after one click, the selection
  region's text includes the date, `"2 events"` (or that day's count) and
  `"Press again to see the events."`.
- `"the hint moves with the selection"`: after clicking the 21st, only the
  21st carries `aria-haspopup` and `aria-describedby`.
- Review Focus 1, `"after navigating, the second tap opens the new day"`:
  press ›, click the 1st twice, and the dialog shows September's 1st.
- Review Focus 2, `"a tap on the overlay closes without selecting"`: open,
  then click the overlay above the 5th. The dialog closes, and the selection
  is still the 21st.
- Review Focus 3, `"an empty day opens on Nothing scheduled."`.
- `"nothing is visible under the grid"`: with the drawer closed, no
  `[data-slot=event-calendar-agenda]` is visible.

- [ ] **Step 2: Run and see them fail**

Run: `bundle exec rspec spec/system/event_calendar_spec.rb -e "the agenda as a drawer"`
Expected: FAIL, with no dialog opened.

- [ ] **Step 3: Implement**

In `select`, when `drawerValue && day === this.selectedValue`, return
`this.openDay(event)`. Do not dispatch.

Otherwise select as now, then `announceSelection()`. That method sets the
region's text to the cell's `aria-label` plus `". "` plus the hint element's
`textContent`.

`markSelection` moves `aria-haspopup`, `aria-expanded` and
`aria-describedby` onto the newly selected cell when `drawerValue` is on.

- [ ] **Step 4: Run the block, then `bin/eslint` and `spec/stimulus_contract_spec.rb`**

Expected: PASS.

- [ ] **Step 5: Commit** — `Open the day's drawer on a second tap`

---

### Task 3: link cells (`day_url:`)

**Files:**
- Modify: `event_calendar_controller.js`, `openDay`.
- Test: `spec/system/event_calendar_spec.rb`. Use the fixture the existing
  `day_url:` examples use (the `density` preview with `turbo` set; grep
  `day_url` in that file) with `agenda: "drawer"`.

- [ ] **Step 1: Write the failing system specs**

- `"a click on another day navigates"`: the URL changes and the clicked day
  is selected after the load.
- `"a click on the selected day opens the drawer instead"`: the URL is
  unchanged and the dialog is visible.
- `"Enter on the selected link opens it"`.
- Review Focus 4, `"a modified click navigates"`: cmd/ctrl-click on the
  selected cell does not open the dialog. Assert on the dialog; a new tab is
  not observable reliably.

- [ ] **Step 2: Run and see them fail**

- [ ] **Step 3: Implement `openDay(event)` for `<a>` cells**

Leave the event alone, so the link navigates, unless all of these hold: the
cell carries `aria-selected="true"`, `event.button === 0`, and none of
`metaKey`, `ctrlKey`, `shiftKey`, `altKey`. When they hold, `preventDefault()`
and open.

Also measure the spec's open question with `agenda_as: :"turbo-frame"`: after
a frame swap, is `aria-selected` stale? If it is, mark the clicked cell
selected in `openDay` before letting the link go. Record what you measured in
the commit message.

- [ ] **Step 4: Run, then the whole `event_calendar_spec.rb` system file**

- [ ] **Step 5: Commit** — `Let a day link open the drawer when it is already the day`

---

### Task 4: moving an event from the drawer, and a Sheet over it

**Files:**
- Modify: `event_calendar_controller.js`, `agendaKeydown` and `cancelPick`.
- Modify: `preview.rb`, an `agenda` param on `event_links`.
- Test: `spec/system/event_calendar_spec.rb`.

- [ ] **Step 1: Write the failing system specs**

- `"Space on a row closes the drawer and the pick goes on on the grid"`:
  `movable` preview with `agenda: :drawer`. Open the 20th, focus a row, press
  Space. The dialog is hidden, the focus is on the 20th cell, → then Space
  moves the event one day.
- `"Escape puts it back without reopening the drawer"`: the focus is on the
  day and no dialog is visible.
- `"a row's Sheet opens over the drawer"`: `event_links` with
  `agenda: "drawer"`. Open the day, click the row whose attributes open the
  Sheet. The Sheet is visible and on top: `elementFromPoint` at its centre is
  inside it. Escape closes the Sheet first, and the drawer is still open.

- [ ] **Step 2: Run and see them fail**

- [ ] **Step 3: Implement**

In `agendaKeydown`, when `drawerValue`, call `this.agendaDrawer?.close()`
before `render()` / `focusDay`. The dialog's focus restore is synchronous in
`teardown`, so the `focusDay` that follows wins. Verify that with the spec
rather than assuming it.

If the Sheet example fails on stacking, stop and report. Do not patch the
dialog layers in this task.

- [ ] **Step 4: Run the system file, then `bundle exec rake`, `bin/rubocop`, `bin/eslint`**

- [ ] **Step 5: Commit** — `Carry a pick from the drawer back to the grid`

---

### Task 5: docs

**Files:**
- Modify: `.claude/docs/features/event-calendar.md`:
  - the Options row for `agenda:`, which adds `:drawer`;
  - a section under *The day view, and letting a host own it* covering the
    gesture, the link cells, the accessibility trade-off, and what was
    measured in Task 3.
- Modify: the spec's status line, from *agreed* to *built*.

- [ ] **Step 1: Write, then check every claim against the file it names**
- [ ] **Step 2: Commit** — `Document the day's agenda as a drawer`
