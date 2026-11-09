# Event calendar: what an event says, and where it opens — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** an event carries generic fields the gem draws on its chip and its list
row, a host colour, and per-event attributes on the row's link — so a host can
open one event in a Sheet and another on its page, with no JavaScript of its own.

**Architecture:** everything starts in `Event` (Task 1). The server-drawn
readings — hours, week, day, workload by event, and every agenda the server
renders — draw it in Tasks 2–4, and a template preview proves the click in
Task 5. The client-drawn month comes **last** (Task 6), because the design's one
open question (two clicks on a desktop month) is about it, and because it is the
expensive part: the payload, the `<template>` prototypes and the clone.

**Tech Stack:** Ruby / ViewComponent, Stimulus, RSpec + Capybara + headless
Chrome, Lookbook.

**Spec:** [`.claude/docs/specs/2026-11-09-event-calendar-event-content-design.md`](../specs/2026-11-09-event-calendar-event-content-design.md)
— read it first. Where this plan and the spec disagree, the spec wins and the
plan is wrong.

## Global Constraints

- **A host that passes none of the new keywords sees no change.** Through Task 5
  no existing golden may move at all. In Task 6 a golden may move **only inside
  the `<template>`** of a client-drawn preview — read the diff, not the count.
- **No field with a Gestart name or meaning** reaches `Event`, a comment, a
  preview or a locale key. The preview's data is about boiler servicing, as the
  dummy's `Appointment` already is.
- **The chip is never a link and never focusable.** It sits inside the day's
  `<a>` or `<button>`; "keeps the day the only thing that can be clicked" must
  stay green.
- **No JavaScript event is emitted for a click.** No id, no type.
- **A host colour is used as `--event-color` only**, with `--event-ink` set to
  `var(--foreground)`. Never derived, never put in a class.
- **Attribute precedence is `data-slot` < component defaults < caller**;
  `class` and `data-action` concatenate.
- **Never split a class string across a `\` line continuation.**
- **Any class no vendored TSX contains goes in `reverse_parity_spec`'s `ours`
  list with its reason.** It reads the goldens, so regenerate them first.
- **Generated files are not hand-edited**: `icons.rb` comes from
  `rake icons:build`.
- Full check before each commit: `bundle exec rake`, `bin/rubocop`, `bin/eslint`.

## Review Focus

1. **A `color:` string that is not a bare custom-property name** —
   `"--x; background: red"`, `"var(--x)"`, `"red"`. Expected: treated as an
   unknown colour (the calendar's fallback), never interpolated into `style`.
   Test in Task 1.
2. **An assignee given as a String alongside a Hash with `status:`** in one
   event. Expected: the String one has no badge, the other has one, and the
   `+N` still counts both. Test in Task 3.
3. **`attributes:` with no `url:`.** Expected: nothing to merge onto — the row
   stays an `<li>` and the attributes are dropped, not put on the `<li>`. Test in
   Task 4.
4. **`attributes:` that try to replace `href` or `data-slot`.** Expected:
   `href` is the event's `url:` and `data-slot` the gem's; `class` and
   `data-action` concatenate. Test in Task 4.
5. **Two events in the same month payload, one with a host colour and one
   with a fixed one, redrawn after a month step.** Expected: the cloned row and
   bar of the fixed one carry no leftover inline `--event-color`. Test in Task 6.

---

### Task 1: `Event` takes the new fields

**Files:**
- Modify: `app/components/shadcn/event_calendar/event.rb`
- Test: `spec/components/shadcn/event_calendar_event_spec.rb`

**Interfaces:**
- Produces, all readers on `Event`:
  - `subtitle` / `description` → `String` or `nil` (blank becomes `nil`)
  - `done?` / `attachment?` → `Boolean`
  - `attributes` → `Hash`, `{}` when not given
  - `color` → one of `COLORS`, **or `:host`**
  - `color_property` → `String` like `"--chart-2"` when `color == :host`, else `nil`
  - `Assignee = Struct.new(:name, :image, :status)`, `status` one of
    `Assignee::STATUSES = %i[done pending]` or `nil`

- [ ] **Step 1: Write the failing examples**

In a new `describe "the fields a host adds"`:

```ruby
it "keeps the texts and flags it is given", :aggregate_failures do
  event = described_class.new(title: "Service", starts_at: Date.new(2026, 8, 20),
                              subtitle: "Rossi", description: "Bring the spare filter",
                              done: true, attachment: true)

  expect(event).to have_attributes(subtitle: "Rossi", description: "Bring the spare filter",
                                   done?: true, attachment?: true)
end

it "says nothing it was not given", :aggregate_failures do
  event = described_class.new(title: "Service", starts_at: Date.new(2026, 8, 20), subtitle: " ")

  expect(event).to have_attributes(subtitle: nil, description: nil, done?: false,
                                   attachment?: false, attributes: {}, color_property: nil)
end

it "takes a host colour as a custom property's name" do
  event = described_class.new(title: "Service", starts_at: Date.new(2026, 8, 20), color: "--chart-2")

  expect(event).to have_attributes(color: :host, color_property: "--chart-2")
end

# Review Focus 1. Anything but a bare name would be interpolated into `style`.
it "refuses anything but a bare custom-property name", :aggregate_failures do
  [ "--x; background: red", "var(--x)", "red", "--" ].each do |value|
    event = described_class.new(title: "Service", starts_at: Date.new(2026, 8, 20), color: value)

    expect(event).to have_attributes(color: :default, color_property: nil)
  end
end

it "gives an assignee a status from a hash, and none from a string", :aggregate_failures do
  event = described_class.new(title: "Service", starts_at: Date.new(2026, 8, 20),
                              assignees: [ "Ada Lovelace", { name: "Grace Hopper", status: :done } ])

  expect(event.assignees.map(&:status)).to eq([ nil, :done ])
end

it "drops a status it does not know" do
  event = described_class.new(title: "Service", starts_at: Date.new(2026, 8, 20),
                              assignees: [ { name: "Grace Hopper", status: :signed } ])

  expect(event.assignees.first.status).to be_nil
end
```

- [ ] **Step 2: Run, expect them to fail**

Run: `bundle exec rspec spec/components/shadcn/event_calendar_event_spec.rb -e "the fields a host adds"`
Expected: FAIL — `unknown keyword: :subtitle`.

- [ ] **Step 3: Implement**

`initialize` gains `subtitle: nil, description: nil, done: false,
attachment: false, attributes: {}`. A host colour is a String matching
`/\A--[a-z0-9-]+\z/i` with at least one character after `--`; anything else goes
through the existing `fallback_color`. `wrap_assignee` reads `:status` from a
Hash and keeps it only if it is in `STATUSES` (as a Symbol). Update the
`@param events` doc in `component.rb` (around line 385) to list the new keys.

- [ ] **Step 4: Run the file, expect it to pass**

Run: `bundle exec rspec spec/components/shadcn/event_calendar_event_spec.rb`

- [ ] **Step 5: Commit** — `git commit -m "Let an event carry what a host wants it to say"`

---

### Task 2: a host colour, drawn by the server

**Files:**
- Modify: `app/components/shadcn/event_calendar/component.rb` — a helper, and
  `agenda_item`
- Modify: `app/components/shadcn/event_calendar/hours/component.rb` — `bar`, `chip`
- Modify: `app/components/shadcn/event_calendar/workload/component.rb` — `item_chip`
- Test: `spec/components/shadcn/event_calendar_spec.rb`

**Interfaces:**
- Consumes: `Event#color`, `Event#color_property` (Task 1)
- Produces: private `color_style(event) -> String` on the base component —
  `"--event-color:var(--chart-2);--event-ink:var(--foreground);"` for a host
  colour, `""` otherwise. Every element that writes `"data-color": event.color`
  prepends it to its `style` (or gets `style:` only when non-empty).

- [ ] **Step 1: Write the failing examples**

```ruby
describe "a host colour" do
  let(:events) do
    [ { title: "Service", starts_at: Time.zone.local(2026, 8, 5, 9), color: "--chart-2", url: "/e/1" },
      { title: "Survey", starts_at: Time.zone.local(2026, 8, 5, 11), color: :blue, url: "/e/2" } ]
  end

  it "sets the mark and leaves the ink neutral, on the chip and the row", :aggregate_failures do
    render_inline(described_class.new(month: Date.new(2026, 8, 1), reading: :weekly,
                                      selected: Date.new(2026, 8, 5), window: (7..19),
                                      day_url: ->(day) { "/d/#{day}" }, events:))

    host = [ parts("event-calendar-day-item").first, parts("event-calendar-agenda-item").first ]
    expect(host.map { |node| node["data-color"] }).to all(eq("host"))
    expect(host.map { |node| node["style"] })
      .to all(include("--event-color:var(--chart-2);--event-ink:var(--foreground);"))
  end

  it "writes no style for a fixed colour" do
    render_inline(described_class.new(month: Date.new(2026, 8, 1), reading: :weekly,
                                      selected: Date.new(2026, 8, 5), window: (7..19),
                                      day_url: ->(day) { "/d/#{day}" }, events:))

    expect(parts("event-calendar-agenda-item").last["style"]).to be_nil
  end
end
```

(`parts` is the helper already used in this file.) Add one more for the hours
`bars` shape (`event-calendar-day-bar`) and one for the workload by event
(`reading: :workload, group: :event`, its `item_chip`'s slot).

- [ ] **Step 2: Run, expect them to fail** on `data-color` being `"default"`.

- [ ] **Step 3: Implement `color_style`** and use it at each `data-color`. The
  inline custom properties win over `COLOR_TOKENS`' `[&_[data-color=…]]` rules
  by being inline, so `COLOR_TOKENS` is not touched and no class is added.

- [ ] **Step 4: Run the event calendar specs and the snapshots**

Run: `bundle exec rspec spec/components/shadcn/event_calendar_spec.rb spec/snapshot_spec.rb`
Expected: PASS, **and no golden moves** (`git status spec/fixtures` clean).

- [ ] **Step 5: Commit** — `git commit -m "Let a host colour an event with a property of its own"`

---

### Task 3: the chip says more

**Files:**
- Modify: `app/components/shadcn/event_calendar/chips.rb` — `chip_head`,
  `chip_text`, `avatar_for`
- Modify: `config/locales/en.yml`
- Add: `vendor/lucide/icons/paperclip.svg`, then regenerate `icons.rb`
- Test: `spec/components/shadcn/event_calendar_spec.rb`

**Interfaces:**
- Consumes: Task 1's readers.
- Produces: slots `event-calendar-day-done`, `event-calendar-day-attachment`,
  `event-calendar-day-subtitle`, and `avatar-badge` with `data-status`. Locale
  keys `event_calendar.done`, `event_calendar.attachment`,
  `event_calendar.assignee_status.done`, `event_calendar.assignee_status.pending`.

The layout is the spec's default: the head keeps time, span and avatars, and
gains the two icons; title and subtitle share one truncated line; **no
description on the chip**. The chip stays non-interactive.

- [ ] **Step 1: Vendor the icon**

Fetch `paperclip.svg` from `lucide-static` at the version in
`vendor/lucide/REVISION` (`https://unpkg.com/lucide-static@<version>/icons/paperclip.svg`)
into `vendor/lucide/icons/`, then `bundle exec rake icons:build`. `check` is
already vendored.

- [ ] **Step 2: Write the failing examples** — on a weekly render of one event
  with `subtitle: "Rossi"`, `done: true`, `attachment: true` and assignees
  `[ "Ada Lovelace", { name: "Grace Hopper", status: :done } ]`:

```ruby
it "draws the flags as icons with names", :aggregate_failures do
  expect(parts("event-calendar-day-done").first.text).to include("Done")
  expect(parts("event-calendar-day-attachment").first.text).to include("Has an attachment")
end

it "puts the subtitle on the title's line" do
  expect(parts("event-calendar-day-subtitle").first.text).to eq("Rossi")
end

it "keeps the description off the chip" do
  expect(painted.css("[data-slot=event-calendar-day-item]").text).not_to include("spare filter")
end

# Review Focus 2.
it "badges only the assignee with a status", :aggregate_failures do
  badges = painted.css("[data-slot=event-calendar-day-item] [data-slot=avatar-badge]")
  expect(badges.map { |badge| badge["data-status"] }).to eq([ "done" ])
  expect(badges.first.text).to include("Done")
end
```

And one asserting an event with none of the fields renders the chip
byte-identical to before — the snapshot does that for every existing preview,
so this one is the snapshot run in Step 5.

- [ ] **Step 3: Run, expect them to fail.**

- [ ] **Step 4: Implement.** Icons are `Icon::Component` with an `sr-only`
  name beside them (the chip's text is read inside the day's target, so a name
  matters). The badge is `Avatar::Badge::Component` with `data-status`, an
  `sr-only` name from `event_calendar.assignee_status.<status>`, and for
  `:pending` the class `bg-muted-foreground` merged over upstream's
  `bg-primary` — `:done` keeps upstream's. Locale strings: "Done", "Has an
  attachment", "Done", "Pending".

- [ ] **Step 5: Run the specs, the snapshots and reverse parity**

```bash
bundle exec rspec spec/components/shadcn/event_calendar_spec.rb spec/snapshot_spec.rb spec/icons_spec.rb
bundle exec rspec spec/reverse_parity_spec.rb
```

Expected: no golden moves. Reverse parity reads the goldens, and no golden yet
renders the new parts, so it is re-run in Task 5.

- [ ] **Step 6: Commit** — `git commit -m "Let a chip say whether it is done, what it carries, and who has finished"`

---

### Task 4: the row says everything, and carries the host's attributes

**Files:**
- Modify: `app/components/shadcn/event_calendar/component.rb` — `agenda_row`
- Test: `spec/components/shadcn/event_calendar_spec.rb`

**Interfaces:**
- Consumes: Tasks 1 and 3 (`avatar_for`, the icons, the locale keys).
- Produces: in the row, slots `event-calendar-agenda-subtitle`,
  `event-calendar-agenda-description`, `event-calendar-agenda-avatars`, and the
  same `-done` / `-attachment` names as the chip with `agenda` for `day`. The
  host's `attributes:` are merged onto the row's `<a>`.

- [ ] **Step 1: Write the failing examples** — on a weekly render with
  `day_url:` and the event of Task 3 plus `description:`, `url: "/e/1"` and
  `attributes: { data: { turbo_frame: "event", action: "shadcn--dialog#open" } }`:

```ruby
it "reads everything out in full", :aggregate_failures do
  row = parts("event-calendar-agenda-row").first
  expect(row.at_css("[data-slot=event-calendar-agenda-subtitle]").text).to eq("Rossi")
  expect(row.at_css("[data-slot=event-calendar-agenda-description]").text).to eq("Bring the spare filter")
  expect(row.css("[data-slot=avatar]").size).to eq(2)
  expect(row.css("[data-slot=avatar-badge]").map { |badge| badge["data-status"] }).to eq([ "done" ])
end

it "puts the host's attributes on the link", :aggregate_failures do
  link = parts("event-calendar-agenda-row").first
  expect(link.name).to eq("a")
  expect(link["data-turbo-frame"]).to eq("event")
  expect(link["data-action"]).to include("shadcn--dialog#open")
end

# Review Focus 4.
it "keeps its own href and slot, and joins classes" do
  # attributes: { href: "/elsewhere", "data-slot": "x", class: "ring-2" }
  link = parts("event-calendar-agenda-row").first
  expect([ link["href"], link["data-slot"], link["class"].include?("ring-2") ])
    .to eq([ "/e/1", "event-calendar-agenda-row", true ])
end

# Review Focus 3.
it "drops attributes it has no link to put them on" do
  # url: nil, attributes: { data: { turbo_frame: "event" } }
  expect(painted.css("[data-turbo-frame]")).to be_empty
end
```

- [ ] **Step 2: Run, expect them to fail.**

- [ ] **Step 3: Implement.** The subtitle joins the title line; the
  description is a second `Item::Description` under the meta line; the avatars
  reuse `chip_avatars` (move it to wherever both can reach it if it is not
  already — `Chips` is included by the readings that draw chips, not by the
  base). Merge with the gem's precedence: the caller's hash goes last, then
  `href` and `data-slot` are set after it; `class` and `data-action` are joined.

- [ ] **Step 4: Run event calendar specs and snapshots — no golden moves.**

- [ ] **Step 5: Commit** — `git commit -m "Let a row read an event out in full, and open where the host says"`

---

### Task 5: a preview that opens one event in a Sheet and sends another to its page

**Files:**
- Create: `app/components/shadcn/event_calendar/previews/event_links.html.erb`
- Modify: `app/components/shadcn/event_calendar/preview.rb` — a `def event_links;
  render_with_template; end` with its comment
- Modify: `test/dummy/config/routes.rb`, `test/dummy/app/controllers/calendar_controller.rb`
- Create: `test/dummy/app/views/calendar/event.html.erb`
- Test: `spec/system/event_calendar_spec.rb`; goldens via `snapshot_spec`

**Interfaces:**
- Consumes: everything above.
- Produces: route `get "calendar/events/:id" => "calendar#event"`, answering a
  `<turbo-frame id="event">`; the preview `event_calendar/event_links`.

A **template** preview, because only templates get a golden. Shaped like
`panel.html.erb`: the calendar inside a `Sheet` whose content holds
`<turbo-frame id="event">`. `reading: :weekly`, `selected:` a day holding both
events, `day_url: ->(date) { "/calendar/days/#{date.iso8601}" }`, and two events:

1. `url: "/calendar/events/1"`, `attributes: { data: { turbo_frame: "event",
   action: "shadcn--dialog#open" } }`, `color: "--chart-2"`, `subtitle:`,
   `description:`, `done: true`, `attachment: true`, assignees with one `:done`;
2. `url: "/calendar/events/2"`, no attributes, a fixed colour.

`--chart-2` because it is a token every shadcn theme defines in both palettes,
so the preview needs no stylesheet of its own.

- [ ] **Step 1: Write the failing system examples**

```ruby
describe "opening an event from its row" do
  before do
    visit_preview("event_calendar", :event_links)
    wait_for_stimulus
  end

  it "opens it in the Sheet when the host says so" do
    find("[data-slot=event-calendar-agenda-row][href='/calendar/events/1']").send_keys(:enter)

    expect(page).to have_css("[role=dialog] turbo-frame#event", text: "Event 1")
  end

  it "goes to its page when the host says nothing" do
    find("[data-slot=event-calendar-agenda-row][href='/calendar/events/2']").send_keys(:enter)

    expect(page).to have_current_path("/calendar/events/2")
  end
end
```

- [ ] **Step 2: Run, expect them to fail** — no such preview.

- [ ] **Step 3: Add the route, the action, the frame view** ("Event <id>" as
  its heading), the preview method and the template.

- [ ] **Step 4: Regenerate and check**

```bash
SNAPSHOTS=overwrite bundle exec rspec spec/snapshot_spec.rb
git status --short spec/fixtures   # only event_calendar-event_links.html, new
bundle exec rspec spec/reverse_parity_spec.rb
bundle exec rspec spec/system/event_calendar_spec.rb spec/system/accessibility_spec.rb -e event_links
```

Any class reverse parity names (`bg-muted-foreground` on a badge is the likely
one) goes in `ours` with its reason. Axe runs on the new preview in both
palettes; a badge's or an icon's contrast failing there is a real failure.

- [ ] **Step 5: Full check and commit**

```bash
bundle exec rake && bin/rubocop && bin/eslint
git commit -m "Show an event opening in a Sheet, and one going to its page"
```

---

### Task 6: the month drawn in the browser

**Files:**
- Modify: `app/components/shadcn/event_calendar/component.rb` —
  `portable_events`, `prototypes`, `agenda_item`
- Modify: `app/javascript/shadcn/controllers/event_calendar_controller.js` —
  `agendaElement`, `eventElement`
- Test: `spec/components/shadcn/event_calendar_spec.rb`,
  `spec/system/event_calendar_spec.rb`, `spec/stimulus_contract_spec.rb` (run)

**Interfaces:**
- Consumes: Tasks 1–4.
- Produces, payload keys **only when present** (the payload is trimmed per key —
  "every key is paid for two thousand times"): `colorProperty`, `subtitle`,
  `description`, `done`, `attachment`, `assignees` (`[{ name, initials, image?,
  status? }]`), `attributes` (a flat `{ "data-turbo-frame": "event", … }`
  string map, flattened on the server the way `tag` flattens `data:` and
  `aria:`).

- [ ] **Step 1: Write the failing examples**
  - Component: an event with none of the fields has the same payload keys as
    today; one with them has exactly the keys above.
  - System, on the `event_links` events rendered as a month (a second template
    is not needed — `density` already renders any reading; add `event_links`
    data behind a parameter there if needed): after `nav_button("Go to the Next
    Month")` and back, the redrawn row of event 1 has `data-turbo-frame`, the
    subtitle, the description and a `done` badge, and Enter on it opens the
    Sheet.
  - System, Review Focus 5: after the same round trip, the fixed-colour row and
    bar have no `--event-color` in their `style`.
  - System: a `movable:` month whose event has a `url:` — the row is **one**
    tab stop (`li` has no `tabindex`, the `<a>` is the stop), Enter navigates,
    Space picks it up.

- [ ] **Step 2: Run, expect them to fail.**

- [ ] **Step 3: Implement.** The prototype rows gain the parts the server row
  has (subtitle, description, an avatar, a badge, the two icons); the clone
  fills or removes each, as it already does for the dot and the time — the
  direction the existing comment on `prototype_event` says works. A host colour
  is two `style.setProperty` calls; a fixed one removes both. `agenda_item`
  puts `tabindex="0"` on the `<li>` only when the event has no `url:`.

- [ ] **Step 4: Regenerate and read the diff**

```bash
SNAPSHOTS=overwrite bundle exec rspec spec/snapshot_spec.rb
git diff spec/fixtures
```

Every changed line must sit inside `<template data-shadcn--event-calendar-target="prototypes">`.
A line outside it means something is written unconditionally — stop.

- [ ] **Step 5: Full check and commit**

```bash
bundle exec rake && bin/rubocop && bin/eslint
git commit -m "Carry what an event says into the month the browser draws"
```

---

### Task 7: write it down

**Files:**
- Modify: `.claude/docs/features/event-calendar.md`
- Modify: `.claude/docs/todo.md`

- [ ] **Step 1:** In the feature doc, a section after *Moving an event*: the
  generic fields and where each is drawn; the chip as decoration and the row as
  the link, with the `day_url:` contract for the server-drawn readings; the
  host colour as a mark with neutral ink, and why a filled block was not done;
  the rejected host slot and why. Under *Not done*: the desktop month's second
  click, pending a product owner.
- [ ] **Step 2:** In `todo.md`, the open month question as an entry with its
  trigger: "revisit the month alone if two clicks are refused".
- [ ] **Step 3: Commit** — `git commit -m "Write down what an event says, and where it opens"`

---

## Self-review notes

- **Spec coverage.** Fields → T1. Where drawn: chip → T3, row → T4, bars and
  month bars untouched (no task, asserted by unchanged goldens). Chip as
  decoration → Global Constraints + the existing spec. Row as link in month,
  week, day → T4 (server) and T6 (client). `day_url:` contract → T7. Enter →
  T5, T6. Movable one tab stop → T6. Click without JS event → Global
  Constraints. Attributes and precedence → T4. Drawer → T5. Colour → T1, T2, T6.
  Open question → T7, and the order of tasks. Testing section → T2–T6.
- **Names across tasks:** `color_property` (T1) is read in T2 and becomes
  `colorProperty` in T6; `color_style` is T2's alone; the slot names of T3 are
  reused by T4 with `agenda` for `day`.
- **One step refuses to be exact:** T6's month system example may need
  `density` to learn the `event_links` data; the implementer decides, because
  either works and neither changes what is asserted.
