# Event calendar: the week as rows — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** the week offers two views from the panel, **Rows** (the month's
rows-arrangement row for each of its seven days, grouped by event or by
assignee) and **Timeline** (today's week), with the timeline staying the
default.

**Architecture:** what makes a reading *a week* — which week, its title, its
nav step, seven stacked days — moves out of `Weekly::Component` into a module,
`EventCalendar::Week`, so a second class can be a week too (Task 1). The panel
learns that a week has a view question (Task 1). `WeeklyRows::Component <
Workload::Component` includes `Week`, forces `arrangement: :rows`, and is what
`reading: :weekly, arrangement: :rows` hands over to (Task 2). A preview, the
playground and the docs come last (Task 3).

**Tech Stack:** Ruby / ViewComponent, RSpec + Capybara + headless Chrome,
Lookbook.

**Spec:** [`.claude/docs/specs/2026-11-10-event-calendar-week-rows-design.md`](../specs/2026-11-10-event-calendar-week-rows-design.md)
— read it first. Where this plan and the spec disagree, the spec wins.

## Global Constraints

- **`reading: :weekly` alone still draws the timeline.** So does
  `arrangement: :auto` or any value that is not `:rows`.
- **No new word reaches `view_url:`.** A week's view question hands it `:rows`
  or `:hours`, the month's words.
- **No Grid for the week.** Its view question offers Rows and Timeline only.
- **The week stays server-drawn**: `client_drawn?` false, `‹ ›` step a week
  through `month_url:`, `movable:` does not reach it.
- **A chip is never a link and never focusable**; the event opens from the day
  list under the week, which stays in both views (it needs `day_url:`, as now).
- **Goldens:** only `weekly` and `event_links` may move in Task 1 (the panel's
  trigger and menu); Task 3 adds `weekly_rows`. Read each diff.
- **Never split a class string across a `\` line continuation.** Any class no
  vendored TSX contains goes in `reverse_parity_spec`'s `ours`, with its reason.
- Comments and identifiers in English.

## Review Focus

1. **A rows week given the timeline's keywords** (`window:`, `shape:`,
   `shape_url:`) — a host flipping one param — renders without raising and
   without a stray HTML attribute. Test in Task 2.
2. **`arrangement: "rows"` as a string off `params`** hands over to rows, like
   the month's. Test in Task 2.
3. **A week crossing two months in rows** draws seven days, both months, with
   the next month's days `data-outside`. Test in Task 2.
4. **A busy day in rows** caps at three chips and says `+N` (`show_all: false`),
   and draws them all with `show_all: true`. Test in Task 2.
5. **The month's panel does not change**: Grid, Rows, Timeline under "Show the
   month as". The existing system example "narrows from the period to the
   question the view has" must stay green unedited.

---

### Task 1: a week is a module, and its panel asks for a view

**Files:**
- Create: `app/components/shadcn/event_calendar/week.rb`
- Modify: `app/components/shadcn/event_calendar/weekly/component.rb`
- Modify: `app/components/shadcn/event_calendar/component.rb` (`view_panel`,
  `view_options`, `view_label`, around lines 655–730)
- Modify: `app/components/shadcn/event_calendar/daily/component.rb`
- Modify: `config/locales/en.yml` (`event_calendar.view`)
- Test: `spec/components/shadcn/event_calendar_spec.rb` (`describe "the weekly reading"`)
- Goldens: `spec/fixtures/snapshots/event_calendar-weekly.html`, `…-event_links.html`

**Interfaces:**
- Produces: `module Shadcn::EventCalendar::Week` with `period` (`:weekly`),
  `cell_role` (`"listitem"`), `view_choices` (`WEEK_VIEWS`), `view_heading`,
  and the private `week`, `title`, `span_label`, `step_button(direction)`,
  `week_rows` — moved verbatim from `Weekly`, comments included.
- Produces: `EventCalendar::Component::WEEK_VIEWS = %i[rows hours].freeze`.
- Produces on the base: `view_choices` (`VIEWS`) and `view_heading`
  (`shadcn_t("event_calendar.view.label")`); `Daily` overrides
  `view_choices` to `[]`.

- [ ] **Step 1: Write the failing tests** inside `describe "the weekly reading"`:

```ruby
it "asks how to show the week, offering rows and the timeline", :aggregate_failures do
  labels = painted.css("[data-slot=dropdown-menu-label]").map(&:text)
  views = painted.css("[data-slot=dropdown-menu-radio-item]").map { |item| item["data-value"] }

  expect(labels).to include("Show the week as")
  expect(views).to include("rows", "hours")
  expect(views).not_to include("grid")
end

it "checks the timeline and says so on the trigger", :aggregate_failures do
  checked = painted.css("[data-slot=dropdown-menu-radio-item][data-state=checked]").map { |item| item["data-value"] }

  expect(checked).to include("weekly", "hours")
  expect(parts("dropdown-menu-trigger").first.text.squish).to eq("Weekly · Timeline · Chips")
end
```

  And in `describe "#period"`: `expect(checked_period(reading: :weekly)).to eq("weekly")`.

- [ ] **Step 2: Run them, expect FAIL** — no "Show the week as", trigger reads
  "Weekly · Chips".

  Run: `bundle exec rspec spec/components/shadcn/event_calendar_spec.rb -e "the weekly reading" -e "#period"`

- [ ] **Step 3: Implement.**
  - `week.rb`: the module above. `Weekly::Component` keeps `grid` (scale +
    `week_rows`), includes `Week`, and its `view` becomes `:hours` (inherited
    from `Hours`, so delete the override).
  - Base: `view_panel` draws `view_options` when `view_choices.any?` instead of
    `period == :monthly`; `view_options` iterates `view_choices` and labels
    itself `view_heading`; `view_label` says the view when `view_choices.any?`.
  - Locale: `event_calendar.view.week_label: Show the week as`; `Week#view_heading`
    reads it.
  - `daily?` stays `view == :daily`.

- [ ] **Step 4: Run the file, then the snapshots.** The two tests pass and the
  whole file stays green. `bundle exec rspec spec/snapshot_spec.rb` fails on
  `weekly` and `event_links` only; regenerate with
  `SNAPSHOTS=overwrite bundle exec rspec spec/snapshot_spec.rb` and check the
  diff is the trigger text and the added view group, nothing else.

- [ ] **Step 5: Commit** — `Give the week a view question in the panel`.

---

### Task 2: `WeeklyRows`, the week drawn as the month's rows

**Files:**
- Create: `app/components/shadcn/event_calendar/weekly_rows/component.rb`
- Modify: `app/components/shadcn/event_calendar/component.rb` (`self.new`,
  around line 392)
- Test: `spec/components/shadcn/event_calendar_spec.rb` (new
  `describe "the weekly reading, as rows"`, after "the weekly reading")

**Interfaces:**
- Consumes: `Week` (Task 1); `Workload::Component` with `group:`,
  `show_all:`, `show_all_url:`, `group_url:`.
- Produces: `Shadcn::EventCalendar::WeeklyRows::Component < Workload::Component`,
  `include Week`; `initialize(**attributes)` calls
  `super(**attributes, arrangement: :rows)`; `view` → `:rows`;
  `grid` → `tag.div(week_rows, "data-slot": "event-calendar-grid", class: FRAME_CLASS)`
  (no weekday strip, no scale).
- Produces: `Component.new(reading: :weekly, arrangement: :rows)` returns a
  `WeeklyRows::Component`. The check is `arrangement&.to_sym == :rows`, so a
  string works and anything else stays `Weekly`. `WeeklyRows.new` must not
  recurse (the `name == renderer` guard already handles a class handing to
  itself — extend it to this renderer).

- [ ] **Step 1: Write the failing tests.** `options` is
  `{ reading: :weekly, arrangement: :rows, selected: Date.new(2026, 8, 5), events: [ … ] }`
  with "Fit-out" on 5 August at 9:00 assigned to "Ada Lovelace".

```ruby
it "hands over to its own class", :aggregate_failures do
  expect(described_class.new(month: Date.new(2026, 8, 1), **options))
    .to be_a(Shadcn::EventCalendar::WeeklyRows::Component)
  expect(described_class.new(month: Date.new(2026, 8, 1), **options, arrangement: "rows"))
    .to be_a(Shadcn::EventCalendar::WeeklyRows::Component)
  expect(described_class.new(month: Date.new(2026, 8, 1), **options, arrangement: :auto))
    .to be_a(Shadcn::EventCalendar::Weekly::Component)
end

it "draws the seven days as rows, forced at every width", :aggregate_failures do
  expect(parts("event-calendar-day").map { |cell| cell["data-day"] })
    .to eq(%w[2026-08-03 2026-08-04 2026-08-05 2026-08-06 2026-08-07 2026-08-08 2026-08-09])
  expect(parts("event-calendar-day").map { |cell| cell["role"] }).to all(eq("listitem"))
  expect(root["data-arrangement"]).to eq("rows")
  expect(parts("event-calendar-weekdays")).to be_empty
  expect(parts("event-calendar-ruler")).to be_empty
end

it "titles itself with the span and checks rows on the panel", :aggregate_failures do
  expect(parts("event-calendar-title").first.text).to eq("3 – 9 August 2026")
  expect(parts("dropdown-menu-trigger").first.text.squish).to eq("Weekly · Rows · By event")
end

it "groups by event by default, and by assignee when asked", :aggregate_failures do
  expect(parts("event-calendar-day-item").size).to eq(1)
  render_inline(described_class.new(month: Date.new(2026, 8, 1), **options, group: :assignees))
  expect(parts("event-calendar-day-assignee").first.text).to include("Ada Lovelace")
end

it "steps a week through month_url" do
  render_inline(described_class.new(month: Date.new(2026, 8, 1), **options,
                                    month_url: ->(date) { "/m/#{date.iso8601}" }))
  expect(painted.at_css("[aria-label='Go to the Next Week']")["href"]).to eq("/m/2026-08-12")
end

it "keeps the day list under the week, with the event's link", :aggregate_failures do
  render_inline(described_class.new(month: Date.new(2026, 8, 1), **options,
                                    day_url: ->(day) { "/d/#{day}" }))
  expect(parts("event-calendar-agenda")).not_to be_empty
end
```

  Plus the Review Focus tests 1, 3 and 4: `window: (7..19), shape: :bars`
  renders and the root has no `window` or `shape` attribute;
  `selected: Date.new(2026, 8, 31)` gives days `2026-08-31` … `2026-09-06`
  with the September ones `data-outside="true"`; five events on one day render
  three `event-calendar-day-item` and a `event-calendar-day-rest` reading `+2`,
  and five items with `show_all: true`.

  Use the file's existing helpers (`parts`, `painted`, the root lookup the
  other blocks use); add none if one already does the job.

- [ ] **Step 2: Run, expect FAIL** — `reading: :weekly, arrangement: :rows`
  returns a `Weekly::Component`.

  Run: `bundle exec rspec spec/components/shadcn/event_calendar_spec.rb -e "as rows"`

- [ ] **Step 3: Implement** the class and the hand-over in `self.new`. Keep the
  workload row's heat ramp, `CAP` and *Show all* as inherited (the spec's
  default). If one of them turns out wrong for seven rows, stop and say which
  and why in the report rather than changing it.

- [ ] **Step 4: Run the whole spec file and `spec/stimulus_contract_spec.rb`**,
  expect green. No golden should move (`bundle exec rspec spec/snapshot_spec.rb`).

- [ ] **Step 5: Commit** — `Draw the week as the month's rows when asked`.

---

### Task 3: a preview, the playground, and the docs

**Files:**
- Create: `app/components/shadcn/event_calendar/previews/weekly_rows.html.erb`
- Modify: `app/components/shadcn/event_calendar/preview.rb` (`weekly_rows`
  method; `density`: `period` select gains `weekly`, the weekly branch honours
  `view`)
- Test: `spec/system/event_calendar_spec.rb` (`describe "the weekly reading"`)
- Golden: `spec/fixtures/snapshots/event_calendar-weekly_rows.html` (new)
- Docs: `.claude/docs/features/event-calendar.md` (*The period, the week and
  the day*, *One options panel*), `.claude/docs/todo.md`, and tick this plan

**Interfaces:**
- Consumes: Tasks 1–2.

- [ ] **Step 1: Write the failing system test** in `describe "the weekly reading"`:

```ruby
it "switches the week to rows and back to the timeline", :aggregate_failures do
  open_panel
  expect(page.all("[data-slot=dropdown-menu-label]").map(&:text))
    .to eq([ "Show", "Show the week as", "Show each job as" ])

  find("[data-slot=dropdown-menu-radio-item][data-value=rows]").click
  expect(page).to have_css("#{calendar} [data-slot=dropdown-menu-trigger]", text: "Weekly · Rows")
  expect(all("#{calendar} [data-slot=event-calendar-day]").size).to eq(7)

  find("#{calendar} [data-slot=event-calendar-nav] [aria-label='Go to the Next Week']").click
  expect(page).to have_css("#{calendar} [data-slot=event-calendar-title]", text: "10 – 16 August 2026")
  expect(page).to have_css("#{calendar} [data-slot=dropdown-menu-trigger]", text: "Weekly · Rows")
end
```

- [ ] **Step 2: Run, expect FAIL** — the rows item sends you to the monthly
  rows, because `density`'s `view_url` maps every view to `period: "monthly"`.

  Run: `bundle exec rspec spec/system/event_calendar_spec.rb -e "the weekly reading"`

- [ ] **Step 3: Implement.**
  - `density`: a view name keeps `period: "weekly"` when the week is shown, and
    `"monthly"` otherwise; the weekly branch passes `arrangement: :rows` plus
    `group:`, `group_url:`, `show_all:`, `show_all_url:` when `view == "rows"`.
    Add `weekly` to `@param period`.
  - `weekly_rows.html.erb` + a `weekly_rows` method (not `@hidden`): the busy
    generator in August 2026, `selected: 5 August`, by event above and by
    assignee below, each with a heading, all parts rendered in the block.
  - Docs: what the week's two views are, the hand-over rule
    (`arrangement: :rows`), and that the timeline stays the default. Remove or
    update anything in `todo.md` this closes.

- [ ] **Step 4: Run** the system example, then
  `SNAPSHOTS=overwrite bundle exec rspec spec/snapshot_spec.rb` (only the new
  golden appears), then `bundle exec rspec spec/system/accessibility_spec.rb -e weekly_rows`,
  then `bundle exec rake`, `bin/rubocop`, `bin/eslint`. All green.

- [ ] **Step 5: Commit** — `Show the week as rows in the gallery and say what it is`.
