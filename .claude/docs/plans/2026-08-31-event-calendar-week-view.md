# Event calendar week view — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** a weekly period that draws the seven days of the week holding
`selected` as `Hours` rows, aligned on one axis.

**Architecture:** `Weekly::Component < Hours::Component`, a sibling of `Daily`,
overriding `period`, `grid`, `title`, `step_button` and `cell_role`. Before it
can exist the panel has to stop deciding the current period with a two-value
comparison, which is Task 1 and is worth reviewing on its own.

**Tech Stack:** Ruby / ViewComponent, RSpec + Capybara + headless Chrome. No
JavaScript: `Hours::Component#client_drawn?` is `false`, so the week is drawn by
the server and the controller's `render()` returns before touching it.

**Spec:** [`.claude/docs/specs/2026-08-31-event-calendar-week-view-design.md`](../specs/2026-08-31-event-calendar-week-view-design.md)
— read it first, including *What looking at it settled*.

**This code has been run.** A throwaway on `spike/week-view` built it and it
worked: seven rows, the title reading `3 – 9 August 2026`, three periods in the
panel. The code blocks below are that code, not code invented for the plan. What
the spike skipped is everything this plan is actually for — the examples, the
goldens, the `ours` list, and the existing assertions a third period breaks.

## Global Constraints

- **Never split a class string across a `\` line continuation.** Tailwind scans
  source text; half a token generates no CSS.
- **Attribute precedence is `data-slot` < component defaults < caller.**
- **A value an optional feature needs is not written when the feature is off** —
  see `decisions/01-architecture.md`. The goldens are what say so: if a switch
  nobody turned on moves a fixture, something is being written unconditionally.
- **Any class no vendored TSX contains needs an entry in `reverse_parity_spec`'s
  `ours` list, with its reason.** That spec reads the snapshot goldens and
  **not** a live render, so regenerate them before trusting it.
- **Adding a preview is what gets a component into the snapshot, preview and
  accessibility suites.**
- The week inherits `shape: :chips` from `Hours` and changes nothing about it.
- Full check: `bundle exec rake`, then `bin/rubocop` and `bin/eslint`.

---

### Task 1: the period stops being a boolean

No week yet. `period_option` decides what is checked with
`(name == :daily) == daily?`, which cannot express three periods. This is the
smallest change that lets a third exist, and behaviour is identical afterwards —
which is what its test asserts.

**Files:**
- Modify: `app/components/shadcn/event_calendar/component.rb` — `period_option`,
  the panel's `view_options` guard, `view_label`, and a new `period`
- Modify: `app/components/shadcn/event_calendar/daily/component.rb` — `period`
- Test: `spec/components/shadcn/event_calendar_spec.rb`

**Interfaces:**
- Produces: `period`, a private reader returning one of `PERIODS` — `:monthly`
  on the base and `:daily` on `Daily`. Task 2 adds `:weekly` and relies on
  `period_option` comparing `name == period` and on the panel drawing
  `view_options` only when `period == :monthly`.

- [ ] **Step 1: Write the failing test**

In `spec/components/shadcn/event_calendar_spec.rb`, at the end of the top-level
describe:

```ruby
  # The panel used to decide the checked period with `(name == :daily) ==
  # daily?`, which says "there are two of these" in a comparison rather than in
  # a list. Asserted per reading, because the reading is what answers it.
  describe "#period" do
    def checked_period(options)
      render_inline(described_class.new(month: Date.new(2026, 8, 1), **options))
      painted.css("[data-slot=dropdown-menu-radio-item][data-checked]")
             .map { |item| item["data-value"] }
             .find { |value| Shadcn::EventCalendar::Component::PERIODS.map(&:to_s).include?(value) }
    end

    # The readings that have a panel at all: it is a `reading_control`, and the
    # events reading declares none — a plain month renders no trigger and no
    # items, so asking it which period is checked has no answer rather than a
    # wrong one.
    it "is the month's for every monthly reading", :aggregate_failures do
      expect(checked_period(reading: :workload)).to eq("monthly")
      expect(checked_period(reading: :hours)).to eq("monthly")
    end

    it "is nothing at all for a reading with no panel" do
      expect(checked_period({})).to be_nil
    end

    it "is the day's for the daily reading" do
      expect(checked_period(reading: :daily)).to eq("daily")
    end
  end
```

- [ ] **Step 2: Run it, and expect it to pass**

Run: `bundle exec rspec spec/components/shadcn/event_calendar_spec.rb -e "#period"`

**It goes green before the implementation, and that is correct.** This task
changes no output, so its examples characterise what is already true and their
job is to *stay* green through the refactor — a red-first is not available.

The red comes from a control instead, in Step 4: break `period` deliberately and
confirm the examples notice. Without that, an example that asserts nothing is
indistinguishable from one that passes.

Two things this step is guarding against, both found the first time it ran: the
radio item marks itself `data-state="checked"` and **not** `data-checked`, so the
obvious selector finds an empty node set and passes for the wrong reason; and a
plain events calendar has **no options panel at all** — the panel is a
`reading_control` and that reading declares none — so asking it which period is
checked has no answer rather than a wrong one.

- [ ] **Step 3: Introduce `period` and use it**

In `component.rb`, below `daily?`:

```ruby
      # Which of `PERIODS` this reading is. The panel decided it with
      # `(name == :daily) == daily?` — a comparison that can only ever answer
      # for two, and the reason a third could not be added without this.
      def period = :monthly
```

Then the three call sites:

```ruby
          value: name, checked: name == period,
```

```ruby
            safe_join([ period_options, (view_options if period == :monthly), *reading_options ].compact)
```

```ruby
        where = shadcn_t("event_calendar.period.#{period}")
        here = shadcn_t("event_calendar.view.#{view}") if period == :monthly

        safe_join([ where, here, reading_label ].compact, " · ")
```

`where` rather than `period` as the local: the method now owns that name, and a
local shadowing it inside `view_label` is how this reads correctly today and
breaks silently the day someone adds a line below it.

In `daily/component.rb`, beside `def view = :daily`:

```ruby
        def period = :daily
```

- [ ] **Step 4: Run the tests, then break it on purpose**

Run: `bundle exec rspec spec/components/shadcn/event_calendar_spec.rb spec/system/event_calendar_spec.rb`
Expected: PASS, all of them. This task changes no output — `daily?` and
`period == :daily` answer identically while there are two periods, which is
exactly why it is worth doing before the week rather than inside it.

Then the control the green cannot give you: make `Daily#period` return
`:monthly`, run the `#period` examples again, and confirm the failure reads
`expected "daily", got "monthly"`. Put it back.

- [ ] **Step 5: Commit**

```bash
bundle exec rspec spec/snapshot_spec.rb   # must pass without regenerating
bin/rubocop
git add app spec
git commit -m "Let a reading say which period it is"
```

If a golden moves here, something changed that should not have: this task's
whole claim is that the rendered output is identical.

---

### Task 2: the week

**Files:**
- Create: `app/components/shadcn/event_calendar/weekly/component.rb`
- Create: `app/components/shadcn/event_calendar/previews/weekly.html.erb`
- Modify: `app/components/shadcn/event_calendar/component.rb` — `READINGS`,
  `PERIODS`, `RENDERERS`
- Modify: `app/components/shadcn/event_calendar/preview.rb`
- Modify: `config/locales/en.yml`
- Modify: `spec/system/event_calendar_spec.rb:538` and `:564` — two panel
  assertions that list the periods and will gain `"Weekly"`
- Test: `spec/components/shadcn/event_calendar_spec.rb`,
  `spec/system/event_calendar_spec.rb`
- Regenerate: `spec/fixtures/snapshots/`

**Interfaces:**
- Consumes: `period` from Task 1.
- Produces: `Shadcn::EventCalendar::Component.new(reading: :weekly)` returning a
  `Weekly::Component`; `data-slot=event-calendar-weeks` holding seven
  `event-calendar-day` cells with `role="listitem"`.

- [ ] **Step 1: Write the failing component examples**

```ruby
  describe "the weekly reading" do
    let(:options) do
      { reading: :weekly, selected: Date.new(2026, 8, 5), window: (7..19),
        events: [ { title: "Fit-out", starts_at: Time.zone.local(2026, 8, 5, 9) } ] }
    end

    before { render_inline(calendar) }

    it "hands over to its own class" do
      expect(described_class.new(month: Date.new(2026, 8, 1), **options))
        .to be_a(Shadcn::EventCalendar::Weekly::Component)
    end

    it "draws the seven days of the week holding the selection", :aggregate_failures do
      expect(parts("event-calendar-day").size).to eq(7)
      expect(parts("event-calendar-day").map { |cell| cell["data-day"] }.first).to eq("2026-08-03")
      expect(parts("event-calendar-day").map { |cell| cell["role"] }).to all(eq("listitem"))
    end

    it "titles itself with the span, not the month" do
      expect(parts("event-calendar-title").first.text).to eq("3 – 9 August 2026")
    end

    context "with a week that crosses a month" do
      let(:options) { { reading: :weekly, selected: Date.new(2026, 8, 31), window: (7..19) } }

      it "says both months" do
        expect(parts("event-calendar-title").first.text).to eq("31 August – 6 September 2026")
      end
    end

    context "with a selection the month does not contain" do
      let(:options) { { reading: :weekly, selected: Date.new(2026, 9, 20), window: (7..19) } }

      it "falls back to the first week of the grid rather than raising" do
        expect(parts("event-calendar-day").map { |cell| cell["data-day"] }.first)
          .to eq("2026-07-27")
      end
    end
  end
```

- [ ] **Step 2: Run them and watch them fail**

Run: `bundle exec rspec spec/components/shadcn/event_calendar_spec.rb -e "the weekly reading"`
Expected: FAIL — `reading: :weekly` is not in `READINGS`, so it falls back to
`:auto` and draws a month.

- [ ] **Step 3: Register the reading**

In `component.rb`:

```ruby
      READINGS = %i[auto events workload hours daily weekly].freeze
```

```ruby
      PERIODS = %i[monthly weekly daily].freeze
```

```ruby
      RENDERERS = {
        workload: "Shadcn::EventCalendar::Workload::Component",
        hours: "Shadcn::EventCalendar::Hours::Component",
        daily: "Shadcn::EventCalendar::Daily::Component",
        weekly: "Shadcn::EventCalendar::Weekly::Component"
      }.freeze
```

In `config/locales/en.yml`, under `period:`, between `monthly` and `daily`:

```yaml
        weekly: Weekly
```

- [ ] **Step 4: Write the class**

`app/components/shadcn/event_calendar/weekly/component.rb`:

```ruby
# frozen_string_literal: true

module Shadcn
  module EventCalendar
    module Weekly
      # A week is seven `Hours` rows over one window, so Tuesday at ten sits
      # directly above Thursday at ten. It is `Daily`'s sibling rather than its
      # subclass: what the two share is being a period that is not the month,
      # and `Daily`'s nav steps a day.
      class Component < Hours::Component
        def view = :weekly

        def period = :weekly

        def cell_role = "listitem"

        private

        # The week of the rendered grid that holds `selected`, falling back to
        # the first rather than raising: a host can pass a `selected` this month
        # does not contain, and `default_selection` answers the same question
        # for a day by taking the first of the month.
        def week
          @week ||= schedule.weeks.find { |candidate| candidate.days.include?(selected) } ||
                    schedule.weeks.first
        end

        def title
          tag.div(span_label,
                  "data-slot": "event-calendar-title", class: TITLE_CLASS,
                  role: "status", "aria-live": "polite")
        end

        # "3 – 9 August 2026", the month said twice when the week crosses one,
        # and the year too when it crosses that — the cases a fixture month
        # sitting inside a single month makes easy to forget.
        def span_label
          from = week.days.first
          to = week.days.last
          opening =
            if from.year != to.year then I18n.l(from, format: "%-d %B %Y")
            elsif from.month != to.month then I18n.l(from, format: "%-d %B")
            else from.strftime("%-d")
            end

          "#{opening} – #{I18n.l(to, format: '%-d %B %Y')}"
        end

        # `‹` and `›` step a week here, not a month.
        def step_button(direction)
          target = selected + (direction == :previous ? -7 : 7)

          nav_button(target, size: :"icon-sm", action: STEP_ACTIONS.fetch(direction),
                     label: shadcn_t("event_calendar.#{direction}_week")) do
            render(Icon::Component.new(direction == :previous ? "chevron-left" : "chevron-right",
                                       class: CHEVRON_CLASS))
          end
        end

        # Seven rows and the scale above them — no weekday strip and no
        # `role="grid"`, because seven stacked days are a list and the
        # seven-column geometry a grid role would report does not exist here.
        def grid
          tag.div(safe_join([ scale, week_rows ].compact),
                  "data-slot": "event-calendar-grid", class: FRAME_CLASS)
        end

        def week_rows
          cells = week.days.map do |day|
            day_cell(day, on_day: schedule.on(day), assignees: schedule.assignees_on(day), hidden: 0)
          end

          tag.div(safe_join(cells),
                  "data-slot": "event-calendar-weeks", class: WEEKS_CLASS,
                  role: "list", "aria-label": span_label)
        end
      end
    end
  end
end
```

`previous_week` and `next_week` are new locale keys — add them beside
`previous_day` and `next_day`:

```yaml
      previous_week: Go to the Previous Week
      next_week: Go to the Next Week
```

- [ ] **Step 5: Run the component examples**

Run: `bundle exec rspec spec/components/shadcn/event_calendar_spec.rb -e "the weekly reading"`
Expected: PASS.

- [ ] **Step 6: Add the preview — a template, and only a template**

`snapshot_spec` globs `*/previews/*.html.erb`, so **a method preview gets no
golden**. That is decisive here: the week needs the fixture more than it needs
parameters, because a silent change to its markup would otherwise be caught by
nothing.

Which means the preview cannot drive its own nav. A server-drawn reading's `‹`
and `›` are links, links need a `month_url:`, and a `month_url:` needs somewhere
to point — a parameter a template has not got. Step 8 uses `density` for that
instead, which is the preview built for exactly this and which already walks the
month and the day the same way.

`app/components/shadcn/event_calendar/previews/weekly.html.erb`:

```erb
<%# A busy week rather than a quiet one: the shape a week takes is decided by
    its most crowded day's lanes, and a light fixture hides that. %>
<%= render(Shadcn::EventCalendar::Component.new(
      reading: :weekly,
      month: Date.new(2026, 8, 1),
      selected: Date.new(2026, 8, 5),
      window: (7..19),
      events: Shadcn::EventCalendar::Preview.workload_events
    )) %>
```

In `preview.rb`, beside the other examples:

```ruby
      # A week: seven days of the hours axis over one window, so the same hour
      # is the same x on every row. `‹` and `›` step a week.
      def weekly
        render_with_template
      end
```

- [ ] **Step 7: Fix the two panel assertions a third period breaks**

`spec/system/event_calendar_spec.rb` asserts the panel's radio items exactly, in
two places. Both gain `"Weekly"` after `"Monthly"`:

```ruby
        .to eq([ "Monthly", "Weekly", "Daily", "Grid", "Rows", "Timeline", "By assignee", "By event" ])
```

```ruby
        .to eq([ "Monthly", "Weekly", "Daily", "Timeline only", "List only", "Timeline and list",
                 "Chips", "Bars", "By assignee", "By event" ])
```

These are not incidental churn: they are the examples that would have caught a
third period being added badly, and they should be read before being edited.

- [ ] **Step 8: A system example for the nav**

```ruby
  describe "the weekly reading" do
    before do
      visit_preview("event_calendar", :weekly)
      wait_for_stimulus
    end

    it "steps a week rather than a month", :aggregate_failures do
      expect(find("#{calendar} [data-slot=event-calendar-title]").text).to eq("3 – 9 August 2026")

      nav_button("Go to the Next Week").click

      expect(find("#{calendar} [data-slot=event-calendar-title]").text).to eq("10 – 16 August 2026")
    end
  end
```

**Not `nav_button`.** That helper finds a `button`, and `nav_button` in the
component renders an `<a>` when it has an `href` — which it does here, because
this reading is drawn by the server and its nav is links. The example finds the
`[aria-label=…]` without naming a tag.

`density` also has to learn the period: `weekly = period.to_s == "weekly"`, the
`view_url` case gains `"weekly"` beside `"daily"` and `"monthly"`, and an `args`
branch merges `reading: :weekly` with the window and the shape. Its existing
`month_url:` needs no change — the week hands it `selected ± 7`, and the month
of that date is the grid the week is found in, including the step that crosses
into September.

- [ ] **Step 9: Regenerate, declare, and run everything**

```bash
SNAPSHOTS=overwrite bundle exec rspec spec/snapshot_spec.rb
bundle exec rspec spec/reverse_parity_spec.rb
```

`event_calendar-weekly.html` appears, **and four existing goldens move** — the
readings that have an options panel, which all gain the new *Weekly* item. That
is correct and the diff proves it: every changed line belongs to that one radio
item and its indicator. Read the diff rather than accepting the count; a change
anywhere but in the panel means something is being written unconditionally,
which is the trap Task 1's commit message names.

Reverse parity will name any class the week renders that no vendored TSX has.
There should be none — every class here comes from `Hours` — but read what it
prints rather than assuming.

```bash
bundle exec rake && bin/rubocop && bin/eslint
git add app spec config
git commit -m "Draw a week as seven rows of one axis"
```

---

### Task 3: what the week changes, and the one thing it does not

**Files:**
- Modify: `.claude/docs/features/event-calendar.md`
- Modify: `.claude/docs/todo.md`

- [ ] **Step 1: Give the feature doc the week**

In *Three readings, three components* — which the week makes four — and in *The
period, and the day*, which becomes the period, the week and the day. Carry over
from the spec: seven rows over one window; the empty day at full height and why;
the two shapes measured at 1565px and 577px against an 802px viewport, with the
default staying `chips`; and that the week has no grouping because `Hours` has
none, which is the third piece.

- [ ] **Step 2: Close the week's TODO entry**

`todo.md` carries **The event calendar's week view** under *Smaller things*. It
comes off.

- [ ] **Step 3: Correct the split entry, whose trigger did not fire**

This is the step to read carefully. The entry **Split
`event_calendar_controller.js`** ends:

> **What changes the answer is the week view above.** It needs a `render` of its
> own, which gives the base its second subclass and brings the three hooks to
> life — at which point the split pays for itself instead of being paid for in
> advance.

The week has arrived and **it needs no `render` of its own**:
`Hours::Component#client_drawn?` is `false`, so the controller returns before
drawing and the week is served whole by the server. The predicted trigger did
not fire, and the entry must say so rather than be left pointing at a week that
now exists.

What replaces it: the trigger is a *client-drawn* second reading, which is a
thing no reading has needed yet — the three server-drawn ones exist precisely
because their data should not travel.

- [ ] **Step 4: Commit**

```bash
git add .claude/docs
git commit -m "Write down the week, and the trigger it did not pull"
```

---

## Self-review notes

- **Spec coverage.** Seven aligned rows → Task 2's `week_rows`. The period
  cleanup → Task 1. The fallback → Task 2 Step 1's third context. Title span and
  month-crossing → Task 2, both asserted. `role="list"`/`listitem` → Task 2. The
  empty day at full height → nothing to implement: it is what `day_cell` already
  does, and the decision is recorded in Task 3. `chips` default → nothing to
  implement, and the Global Constraints say so. Public API → Task 2's `READINGS`
  and `PERIODS`, and Task 3's docs.
- **What this plan adds to the spec:** the two existing panel assertions
  (Task 2, Step 7) and the split entry's unfired trigger (Task 3, Step 3).
  Neither was visible until the week was written.
- **Names across tasks:** `period` is defined in Task 1 and returned as
  `:weekly` in Task 2; `week`, `span_label` and `week_rows` are Task 2's alone
  and nothing later reads them.
- **Two steps deliberately refuse to predict a failure** — Task 1 Step 2 and
  Task 2 Step 8 — because both have a plausible wrong answer that would make an
  example pass while asserting nothing.
