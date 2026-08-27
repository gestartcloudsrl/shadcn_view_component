# Event calendar drag-to-move — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** let a host move an event to another day, from the keyboard and from a
pointer, with the browser drawing the move at once and the server having the
last word.

**Architecture:** the component gains `movable: true`, which renders two
affordances and nothing else. The controller writes a move by **assigning
`this.eventsValue`** — not by mutating `this.events` — so a Turbo morph
carrying the server's answer is a value change the controller hears, and then
dispatches `shadcn--event-calendar:event-move`. The gem never talks to a server.

**Tech Stack:** Ruby / ViewComponent / Stimulus, RSpec + Capybara + headless
Chrome. No new dependencies — the gem ships no npm package.

**Spec:** [`.claude/docs/specs/2026-08-27-event-calendar-drag-to-move-design.md`](../specs/2026-08-27-event-calendar-drag-to-move-design.md)
— read it first. Every number quoted below comes from it.

## Global Constraints

- **Never split a class string across a `\` line continuation.** Tailwind scans
  source text; half a token generates no CSS.
- **The controller has no classes of its own.** Every shape is cloned from the
  `<template>` the component renders; state is `data-*` the Ruby styles with
  `data-[…]:` variants.
- **The controller has no text of its own.** Labels arrive as Stimulus values.
- **Attribute precedence is `data-slot` < component defaults < caller.**
- **Any class no vendored TSX contains needs an entry in `reverse_parity_spec`'s
  `ours` list, with its reason.** That spec reads `spec/fixtures/snapshots/*.html`,
  **not** a live render — so regenerate snapshots (`SNAPSHOTS=overwrite bundle
  exec rspec spec/snapshot_spec.rb`) before trusting it.
- **Only the events reading.** `render()` returns on `client_drawn?`; the other
  readings ship no payload and must not start.
- **Adding a preview is what gets a component into the snapshot, preview and
  accessibility suites.**
- Full check: `bundle exec rake`, then `bin/rubocop` and `bin/eslint`.

---

### Task 1: an event carries an identity, and `movable:` insists on one

`Event#id` is `nil` unless a host passed one. A move without an id dispatches
`id: null`, so `movable: true` requires one and says so at render.

**Files:**
- Modify: `app/components/shadcn/event_calendar/component.rb` — `#initialize`,
  `#event_bar`, `#agenda_item`, `#element_attributes`
- Modify: `app/javascript/shadcn/controllers/event_calendar_controller.js` —
  `static values`, `eventElement`, `agendaElement`
- Test: `spec/components/shadcn/event_calendar_spec.rb`
- Regenerate: `spec/fixtures/snapshots/event_calendar-*.html`

**Interfaces:**
- Produces: `movable?` (Ruby, private reader), the value
  `data-shadcn--event-calendar-movable-value`, and `data-event-id` on both
  `[data-slot=event-calendar-event]` and `[data-slot=event-calendar-agenda-item]`.
  Every later task reads `chip.dataset.eventId` / `row.dataset.eventId`.

- [ ] **Step 1: Write the failing tests**

In `spec/components/shadcn/event_calendar_spec.rb`, inside the top-level
describe:

```ruby
  describe "movable" do
    let(:events) do
      [ { id: "a", title: "Conference", starts_at: Date.new(2026, 8, 19), ends_at: Date.new(2026, 8, 21) },
        { id: "b", title: "Standup", starts_at: Time.zone.local(2026, 8, 20, 9, 0) } ]
    end

    context "when it is on" do
      let(:options) { { events:, selected: Date.new(2026, 8, 20), movable: true } }

      it "names the event on every bar and every agenda row", :aggregate_failures do
        expect(parts("event-calendar-event").map { |bar| bar["data-event-id"] }).to eq(%w[a b])
        expect(parts("event-calendar-agenda-item").map { |row| row["data-event-id"] }).to eq(%w[a b])
      end

      it "crosses the switch to the controller" do
        expect(painted.at_css("[data-slot=event-calendar]")["data-shadcn--event-calendar-movable-value"])
          .to eq("true")
      end

      context "with an event carrying no id" do
        let(:events) { [ { title: "Nameless", starts_at: Date.new(2026, 8, 20) } ] }

        it "says which event, rather than moving nothing" do
          expect { rendered_content }.to raise_error(ArgumentError, /Nameless/)
        end
      end
    end

    context "when it is off" do
      let(:options) { { events:, selected: Date.new(2026, 8, 20) } }

      it "writes no identity at all" do
        expect(parts("event-calendar-event").map { |bar| bar["data-event-id"] }).to all(be_nil)
      end
    end
  end
```

- [ ] **Step 2: Run them and watch them fail**

Run: `bundle exec rspec spec/components/shadcn/event_calendar_spec.rb -e movable`
Expected: FAIL — `unknown keyword: :movable`.

- [ ] **Step 3: Take the keyword, and check it**

In `#initialize`, add `movable: false` to the signature (after `agenda_attributes: {}`)
and, after `@schedule` is built:

```ruby
        @movable = !!movable
        require_identities! if @movable
```

Beside the other private readers add `movable` to the `attr_reader` list, and:

```ruby
      # A move dispatches the host's own id, and `Event#id` is `nil` unless the
      # host passed one — it has existed for `#portable_events` and nothing has
      # needed it since. Left to itself this ships `id: null` inside a
      # `CustomEvent`, which fails as "dragging does nothing" days later and in
      # somebody else's code. So it is a render-time error, and it names the
      # event rather than the count.
      def require_identities!
        nameless = schedule.events.find { |event| event.id.blank? }
        return unless nameless

        raise ArgumentError,
              "EventCalendar(movable: true) needs an id on every event; #{nameless.title.inspect} has none"
      end

      def movable? = movable
```

- [ ] **Step 4: Write the identity into both places**

In `#event_bar`, beside `"data-slot": "event-calendar-event"`:

```ruby
          "data-event-id": (event.id if movable?),
```

In `#agenda_item`, on the `tag.li`:

```ruby
               "data-event-id": (event.id if movable?),
```

In `#element_attributes`, beside the other values:

```ruby
          "data-shadcn--event-calendar-movable-value" => movable?.to_s,
```

- [ ] **Step 5: Give the controller the value and the clone half**

In `static values`, after `clientDrawn`:

```js
    movable: { type: Boolean, default: false },
```

In `eventElement`, after `node.dataset.color = event.color`:

```js
    if (this.movableValue) node.dataset.eventId = event.id
```

In `agendaElement`, after `node.dataset.color = event.color`:

```js
    if (this.movableValue) node.dataset.eventId = event.id
```

- [ ] **Step 6: Run the tests and the neighbours**

Run: `bundle exec rspec spec/components/shadcn/event_calendar_spec.rb spec/system/event_calendar_spec.rb`
Expected: PASS.

- [ ] **Step 7: Regenerate the goldens and commit**

```bash
SNAPSHOTS=overwrite bundle exec rspec spec/snapshot_spec.rb
bundle exec rspec spec/reverse_parity_spec.rb spec/snapshot_spec.rb
bin/rubocop && bin/eslint
git add app spec
git commit -m "Give a movable event an identity, and refuse one without"
```

The goldens should not change — no preview passes `movable:` yet. If they do,
something is writing the attribute unconditionally.

---

### Task 2: the agenda row becomes an `Item`

The grip in Task 5 needs somewhere to live. The row is an `Item` written out by
hand; make it one. **Host-visible**: `event-calendar-agenda-mark` goes, and the
title and the meta become `item-title` and `item-description`.

**Files:**
- Modify: `app/components/shadcn/event_calendar/component.rb` — the four
  `AGENDA_*` constants and `#agenda_row`
- Modify: `app/javascript/shadcn/controllers/event_calendar_controller.js` —
  `agendaElement`
- Modify: `spec/components/shadcn/event_calendar_spec.rb`,
  `spec/system/event_calendar_spec.rb`, `spec/reverse_parity_spec.rb`
- Regenerate: `spec/fixtures/snapshots/event_calendar-*.html`

**Interfaces:**
- Produces: an agenda row whose title is `[data-slot=item-title]` and whose
  time is `[data-slot=item-description]`, inside
  `[data-slot=event-calendar-agenda-row]`. Task 5 hangs the grip off it.

- [ ] **Step 1: Write the failing test**

In `spec/components/shadcn/event_calendar_spec.rb`, in the group that already
covers the agenda:

```ruby
    it "describes a row with the Item family's own parts", :aggregate_failures do
      expect(parts("item-title").map(&:text)).to eq(%w[Conference Meeting])
      expect(parts("item-description").map(&:text).last).to eq("10:30 AM – 11:30 AM")
      expect(parts("event-calendar-agenda-mark")).to be_empty
    end
```

- [ ] **Step 2: Run it and watch it fail**

Run: `bundle exec rspec spec/components/shadcn/event_calendar_spec.rb -e "Item family"`
Expected: FAIL — `item-title` finds nothing.

- [ ] **Step 3: Replace the constants**

```ruby
      # What the agenda wants that `Item`'s own `size: :sm` does not give it:
      # its rows are dense, and its two lines are top-aligned.
      AGENDA_ITEM_CLASS = "items-stretch px-2 py-2"
      AGENDA_CONTENT_CLASS = "min-w-0 gap-0.5"
      AGENDA_EVENT_TITLE_CLASS = "truncate font-medium"
      AGENDA_META_CLASS = "truncate text-xs"
```

Delete `AGENDA_MARK_CLASS` and `AGENDA_BODY_CLASS`.

- [ ] **Step 4: Rewrite the row**

```ruby
      # The row *is* an `Item` — a media, a content, a title and a description
      # was the shape it had already, written out by hand.
      def agenda_row(event)
        body = render(Item::Content::Component.new(class: AGENDA_CONTENT_CLASS).with_content(
          safe_join([
            render(Item::Title::Component.new(class: AGENDA_EVENT_TITLE_CLASS).with_content(event.title)),
            render(Item::Description::Component.new(class: AGENDA_META_CLASS)
                                              .with_content(agenda_meta(event)))
          ])
        ))

        # Only one of the two can be an `<a>` and a clone cannot change its own
        # tag name — which is why the `<template>` at the bottom holds both.
        return render(agenda_item_component.with_content(body)) if event.url.blank?

        render(agenda_item_component(as: :a, href: event.url,
                                     class: "#{AGENDA_ITEM_CLASS} #{AGENDA_LINK_CLASS}").with_content(body))
      end

      def agenda_item_component(**attributes)
        Item::Component.new(size: :sm, "data-slot": "event-calendar-agenda-row",
                            **{ class: AGENDA_ITEM_CLASS }.merge(attributes))
      end
```

- [ ] **Step 5: Follow the rename through the controller and the specs**

In `agendaElement`:

```js
    node.querySelector("[data-slot='item-title']").textContent = event.title
    node.querySelector("[data-slot='item-description']").textContent = event.meta
```

Then, in `spec/components/shadcn/event_calendar_spec.rb` and
`spec/system/event_calendar_spec.rb`, replace every
`event-calendar-agenda-event-title` with `item-title` and every
`event-calendar-agenda-meta` with `item-description`.

- [ ] **Step 6: Regenerate the goldens, then let reverse parity speak**

```bash
SNAPSHOTS=overwrite bundle exec rspec spec/snapshot_spec.rb
bundle exec rspec spec/reverse_parity_spec.rb
```

Delete the now-dead `"event-calendar-agenda-mark"` entry from `ours`. Add
nothing else unless the run asks for it by name — it prints the slot and the
classes.

- [ ] **Step 7: Run everything and commit**

```bash
bundle exec rake && bin/rubocop && bin/eslint
git add app spec
git commit -m "Describe an agenda row with the Item family it already was"
```

---

### Task 3: `movable:` renders the two affordances

Nothing moves yet. This is the markup and the CSS, so that Tasks 4 and 5 have
something to drive and a reviewer can look at it.

**Files:**
- Modify: `app/components/shadcn/event_calendar/component.rb` — `EVENT_CLASS`,
  new `EVENT_GRIP_CLASS`, `AGENDA_GRIP_CLASS`, `AGENDA_PICK_CLASS`,
  `#event_bar`, `#agenda_item`, `#agenda_row`
- Modify: `spec/reverse_parity_spec.rb`
- Test: `spec/components/shadcn/event_calendar_spec.rb`

**Interfaces:**
- Produces: `[data-slot=event-calendar-event-grip]` inside every bar and
  `[data-slot=event-calendar-agenda-grip]` inside every agenda row, both only
  when `movable?`; agenda rows take `tabindex="0"` when `movable?`.
  `data-picked` and `data-pending` are styled here and written in Tasks 4–6.

- [ ] **Step 1: Write the failing test**

```ruby
    it "renders a grip on each bar and each row, and only when it is movable", :aggregate_failures do
      expect(parts("event-calendar-event-grip").size).to eq(parts("event-calendar-event").size)
      expect(parts("event-calendar-agenda-grip").size).to eq(parts("event-calendar-agenda-item").size)
      expect(parts("event-calendar-agenda-item").map { |row| row["tabindex"] }).to all(eq("0"))
    end
```

Add its opposite in the `when it is off` context:

```ruby
      it "renders no grip and takes no tab stop", :aggregate_failures do
        expect(parts("event-calendar-event-grip")).to be_empty
        expect(parts("event-calendar-agenda-item").map { |row| row["tabindex"] }).to all(be_nil)
      end
```

- [ ] **Step 2: Run them and watch them fail**

Run: `bundle exec rspec spec/components/shadcn/event_calendar_spec.rb -e movable`
Expected: FAIL — no grips.

- [ ] **Step 3: Add the classes**

Append to `EVENT_CLASS` (a new `" \`-continued segment, never a broken token):

```ruby
                    "data-[picked]:ring-2 data-[picked]:ring-ring data-[pending]:opacity-50"
```

New constants beside it:

```ruby
      # The grip, and only the grip, takes the pointer: the layer stays
      # `pointer-events-none`, so the gaps between bars still belong to the day.
      # Making the whole chip grabbable took the centre of 17 of the 27 days
      # that had events — see the design.
      EVENT_GRIP_CLASS = "pointer-events-auto -ml-0.5 h-full w-2 shrink-0 cursor-grab rounded-l-sm " \
                         "bg-(--event-color)/40 hover:bg-(--event-color)"
```

Beside the agenda's:

```ruby
      # The dot the row used to lead with, become a bar — it is two things at
      # once now: the colour, and what a pointer takes hold of.
      AGENDA_GRIP_CLASS = "w-1.5 shrink-0 cursor-grab self-stretch rounded-full " \
                          "bg-(--event-color)/40 hover:bg-(--event-color)"
      AGENDA_PICK_CLASS = "rounded-md outline-none focus-visible:ring-[3px] focus-visible:ring-ring/50 " \
                          "data-[picked]:bg-accent data-[picked]:ring-2 data-[picked]:ring-ring"
```

- [ ] **Step 4: Render them**

In `#event_bar`, as the first child of the `safe_join`:

```ruby
            (if movable?
               tag.span("", "data-slot": "event-calendar-event-grip", class: EVENT_GRIP_CLASS,
                        "data-action": "pointerdown->shadcn--event-calendar#grab")
             end),
```

In `#agenda_row`, as the first child of the row's `safe_join` — wrap the
existing `body` so the grip is its sibling:

```ruby
        body = safe_join([
          (if movable?
             tag.span("", "data-slot": "event-calendar-agenda-grip", class: AGENDA_GRIP_CLASS,
                      "data-action": "pointerdown->shadcn--event-calendar#grabRow")
           end),
          render(Item::Content::Component.new(class: AGENDA_CONTENT_CLASS).with_content(…))
        ].compact)
```

In `#agenda_item`, when `movable?`, add `tabindex: "0"`,
`class: AGENDA_PICK_CLASS` and
`"data-action": "keydown->shadcn--event-calendar#agendaKeydown"`.

- [ ] **Step 5: Run, regenerate, declare**

```bash
bundle exec rspec spec/components/shadcn/event_calendar_spec.rb
SNAPSHOTS=overwrite bundle exec rspec spec/snapshot_spec.rb
bundle exec rspec spec/reverse_parity_spec.rb
```

Reverse parity will name four slots and their classes. Add one `ours` entry per
slot, each with its reason — `--event-color` is this family's own custom
property, so anything painted from it is ours by construction.

- [ ] **Step 6: Commit**

```bash
git add app spec
git commit -m "Draw what a movable calendar offers, before anything moves"
```

---

### Task 4: the keyboard moves an event

**Files:**
- Modify: `app/javascript/shadcn/controllers/event_calendar_controller.js`
- Test: `spec/system/event_calendar_spec.rb`
- Modify: `app/components/shadcn/event_calendar/preview.rb` + a new
  `app/components/shadcn/event_calendar/previews/movable.html.erb`

**Interfaces:**
- Consumes: `movableValue`, `data-event-id`, `agendaKeydown` (Task 3).
- Produces: `moveEvent(id, shift, focusOn)`, `pickedEvent`, and the dispatched
  `event-move` with `{ id, from, to, revert }`. Task 5 calls `moveEvent`.

- [ ] **Step 1: Add the preview the system spec will drive**

`previews/movable.html.erb`:

```erb
<%# `movable:` needs ids, so this preview names its events — which is also the
    smallest example of what a host has to do. %>
<%= render(Shadcn::EventCalendar::Component.new(
      month: Date.new(2026, 8, 1),
      selected: Date.new(2026, 8, 20),
      movable: true,
      events: Shadcn::EventCalendar::Preview.sample_events.each_with_index.map { |event, index|
        event.merge(id: "e#{index}")
      }
    )) %>
```

In `preview.rb`, beside the other examples:

```ruby
      # Moving an event: `Space` on an agenda row takes it, the arrows move, and
      # `Space` puts it down. The bars carry a grip for a pointer.
      def movable
        render_with_template
      end
```

- [ ] **Step 2: Write the failing test**

In `spec/system/event_calendar_spec.rb`:

```ruby
  describe "moving an event" do
    before do
      visit_preview("event_calendar", :movable)
      wait_for_stimulus
    end

    def row(id) = find("#{calendar} [data-slot=event-calendar-agenda-item][data-event-id='#{id}']")

    def moved = page.evaluate_script(<<~JS)
      (() => {
        const root = document.querySelector("#{calendar}")
        const events = JSON.parse(root.getAttribute("data-shadcn--event-calendar-events-value"))
        const one = events.find((event) => event.id === "e5")
        return [ one.from, one.to ]
      })()
    JS

    # "Standup" is `e5`, on 20 August, which is the selected day — so it is in
    # the agenda, which is the only place a keyboard can take hold of an event.
    it "takes an event from the agenda and puts it on another day", :aggregate_failures do
      expect(moved).to eq(%w[2026-08-20 2026-08-20])

      row("e5").send_keys(:space)
      expect(page.evaluate_script("document.activeElement.dataset.day")).to eq("2026-08-20")

      # `press` goes to the active element, which after a pick is the day cell
      # and not the row — that hand-off is the thing being asserted above.
      press(:arrow_right)
      press(:space)

      expect(moved).to eq(%w[2026-08-21 2026-08-21])
      expect(page.evaluate_script("document.activeElement.dataset.day")).to eq("2026-08-21")
    end

    it "puts the focus back on the row it came from when it is cancelled", :aggregate_failures do
      row("e5").send_keys(:space)
      press(:arrow_right)
      press(:escape)

      expect(moved).to eq(%w[2026-08-20 2026-08-20])
      expect(page.evaluate_script("document.activeElement.dataset.eventId")).to eq("e5")
    end

    it "says nothing to a host that is not listening" do
      expect(page.evaluate_script("window.__moves ?? null")).to be_nil
    end

    it "hands the host an id, two dates and a way back", :aggregate_failures do
      page.execute_script(<<~JS)
        window.__moves = []
        document.addEventListener("shadcn--event-calendar:event-move", (event) => {
          window.__moves.push(event.detail)
          window.__revert = event.detail.revert
        })
      JS

      row("e5").send_keys(:space)
      press(:arrow_right)
      press(:space)

      expect(page.evaluate_script("window.__moves.map((m) => [m.id, m.from, m.to])"))
        .to eq([ %w[e5 2026-08-21 2026-08-21] ])

      page.execute_script("window.__revert()")
      expect(moved).to eq(%w[2026-08-20 2026-08-20])
    end
  end
```

- [ ] **Step 3: Run them and watch them fail**

Run: `bundle exec rspec spec/system/event_calendar_spec.rb -e "moving an event"`
Expected: FAIL — `Space` does nothing; the dates do not change.

- [ ] **Step 4: Implement the hand**

In the controller, under a new heading after `focusCell`:

```js
  // --- moving an event ------------------------------------------------------
  //
  // The agenda is the one place an event is an element. The bars carry
  // `aria-hidden`, so a tab stop on one is an `aria-hidden-focus` violation
  // rather than a design choice — and a crossing event is one *row* there,
  // which is why the keyboard never has to ask which object was grabbed.

  agendaKeydown(event) {
    if (!this.movableValue || event.key !== " ") return

    const row = event.target.closest("[data-slot='event-calendar-agenda-item']")
    if (!row) return

    event.preventDefault()
    this.pickedEvent = this.eventsValue.find((candidate) => candidate.id === row.dataset.eventId)
    this.render()
    this.focusDay(parse(this.selectedValue))
  }

  // `Space` and `Escape` on the grid, added at the head of `keydown` — the
  // arrows below already move the focus, and a pick rides on them unchanged.
  place(day) {
    const picked = this.pickedEvent

    this.pickedEvent = null
    this.moveEvent(picked.id, this.offsetOf(day, parse(picked.from)), day)
  }

  // Both reads happen before the clear: the row to go back to is the picked
  // event's, and `render()` below rebuilds the agenda, so the element has to be
  // found again afterwards rather than held across it.
  cancelPick() {
    const { id, from } = this.pickedEvent

    this.pickedEvent = null
    this.render()

    const row = this.element.querySelector(
      `[data-slot='event-calendar-agenda-item'][data-event-id='${id}']`
    )

    if (row) row.focus()
    else this.focusDay(parse(from))
  }

  // The value, assigned — not `this.events`, mutated behind it. That is what
  // makes a morph correct without the host's help: the attribute changes, so a
  // morph carrying the server's *original* payload back is a change the
  // controller hears, and a refusal lands by itself. Mutating instead left the
  // browser drawing a move the server had thrown away — measured, and written
  // up in the design.
  moveEvent(id, shift, focusOn) {
    if (!shift) return this.redrawAt(focusOn)

    const before = this.eventsValue
    const after = before.map((event) => (
      event.id === id
        ? { ...event,
            from: iso(addDays(parse(event.from), shift)),
            to: iso(addDays(parse(event.to || event.from), shift)),
            pending: true }
        : event
    ))
    const moved = after.find((event) => event.id === id)

    this.eventsValue = after
    this.redrawAt(focusOn)

    this.dispatch("event-move", {
      detail: {
        id, from: moved.from, to: moved.to,
        revert: () => {
          this.eventsValue = before
          this.redrawAt(before.find((event) => event.id === id).from)
        }
      }
    })
  }

  redrawAt(day) {
    this.render()
    this.focusDay(parse(day))
  }
```

At the head of `keydown`, before the `moves` table:

```js
    if (this.movableValue && event.key === " " && this.pickedEvent) {
      event.preventDefault()
      this.place(from)
      return
    }
    if (event.key === "Escape" && this.pickedEvent) {
      event.preventDefault()
      this.cancelPick()
      return
    }
```

In `eventElement`, after the id:

```js
    this.mark(node, "picked", this.pickedEvent && event.id === this.pickedEvent.id)
    this.mark(node, "pending", !!event.pending)
```

and the same two lines in `agendaElement`.

`eventsValueChanged` already rebuilds `this.events` and clears the index, so an
assignment redraws from the value and nothing else has to know.

- [ ] **Step 5: Run the tests**

Run: `bundle exec rspec spec/system/event_calendar_spec.rb -e "moving an event"`
Expected: PASS.

If an example fails on the focus rather than on the dates, the cause is almost
certainly a read of `this.pickedEvent` after it was cleared — `cancelPick` above
destructures first for exactly that reason.

- [ ] **Step 6: Measure what assigning the value costs**

The design says this has to be measured before it is believed. In `bin/console`:

```ruby
events = (1..2000).map { |n| { id: n.to_s, title: "Job #{n}", starts_at: Date.new(2026, 8, 1) + (n % 31) } }
Benchmark.realtime { 200.times { render Shadcn::EventCalendar::Component.new(events:, movable: true) } }
```

Then, in the browser on the `movable` preview with that payload, time 50 moves.
If a move costs more than a frame, fall back to writing only the moved event's
two dates into the attribute rather than the whole array — the callback still
fires, and the idea is unchanged. Record the number either way in
`features/event-calendar.md` (Task 7).

- [ ] **Step 7: Run everything and commit**

```bash
bundle exec rake && bin/rubocop && bin/eslint
git add app spec
git commit -m "Move an event from the keyboard, through the value"
```

---

### Task 5: the pointer moves an event

**Files:**
- Modify: `app/javascript/shadcn/controllers/event_calendar_controller.js`
- Test: `spec/system/event_calendar_spec.rb`

**Interfaces:**
- Consumes: `moveEvent(id, shift, focusOn)` (Task 4), the two grips (Task 3).
- Produces: `grab`, `grabRow`, `dayUnder(x, y)`.

- [ ] **Step 1: Write the failing test**

```ruby
    def grip(id) = find("#{calendar} [data-slot=event-calendar-event][data-event-id='#{id}'] " \
                        "[data-slot=event-calendar-event-grip]", match: :first)

    def haul(from, to)
      page.driver.browser.action.click_and_hold(from.native).move_to(day(to).native).release.perform
    end

    # "Conference" is `e4`, 19–21 August: one bar over three columns. Its grip
    # is on the 19th, so dropping it on the 20th is +1 and not +something else.
    it "shifts by the day the grip is on", :aggregate_failures do
      haul(grip("e4"), "2026-08-20")

      expect(page.evaluate_script(<<~JS)).to eq(%w[2026-08-20 2026-08-22])
        (() => {
          const events = JSON.parse(document.querySelector("#{calendar}")
            .getAttribute("data-shadcn--event-calendar-events-value"))
          const one = events.find((event) => event.id === "e4")
          return [ one.from, one.to ]
        })()
      JS
    end

    # The reason the grip exists rather than the whole chip. Measured at 17 of
    # 27 when the chip was grabbable; the layer stays through, so this is 0.
    it "leaves the day underneath clickable" do
      expect(topmost_over("Conference")).to eq("event-calendar-event")

      day("2026-08-13").click

      expect(day("2026-08-13")["aria-selected"]).to eq("true")
    end
```

- [ ] **Step 2: Run them and watch them fail**

Run: `bundle exec rspec spec/system/event_calendar_spec.rb -e "shifts by the day"`
Expected: FAIL — nothing moves.

- [ ] **Step 3: Implement it**

```js
  // The pointer's shift comes from the day under it, not from the event's own
  // start: a bar is clipped to its week, so an event crossing a Sunday has two
  // grips and the second takes hold of its own Monday. Measured: 7–11 grabbed
  // there and dropped on the 11th becomes 8–12.
  grab(event) {
    if (!this.movableValue) return

    const chip = event.currentTarget.closest("[data-slot='event-calendar-event']")
    const from = this.dayUnder(event.clientX, event.clientY)
    if (!chip || !from) return

    this.startDrag(event, chip.dataset.eventId, from, chip)
  }

  // The agenda row has no day on the grid to be relative to, so the drop day
  // becomes the event's new start. A different gesture, not a cheaper one.
  grabRow(event) {
    if (!this.movableValue) return

    const row = event.currentTarget.closest("[data-slot='event-calendar-agenda-item']")
    const held = this.eventsValue.find((candidate) => candidate.id === row?.dataset?.eventId)
    if (!held) return

    this.startDrag(event, held.id, held.from, row)
  }

  startDrag(event, id, from, marked) {
    const handle = event.currentTarget

    event.preventDefault()
    handle.setPointerCapture(event.pointerId)

    this.drag = { id, from, handle }
    this.mark(marked, "picked", true)

    this.onDrop = (dropped) => this.drop(dropped)
    handle.addEventListener("pointerup", this.onDrop)
    handle.addEventListener("pointercancel", this.onDrop)
  }

  drop(event) {
    const { id, from, handle } = this.drag

    handle.removeEventListener("pointerup", this.onDrop)
    handle.removeEventListener("pointercancel", this.onDrop)
    this.drag = null

    const over = this.dayUnder(event.clientX, event.clientY) || from

    this.moveEvent(id, this.offsetOf(over, parse(from)), over)
  }

  // The bars sit in a `pointer-events-none` layer over the days, so the day is
  // *behind* whatever the pointer is on. `elementsFromPoint` returns the stack
  // rather than the top of it, which is the only way to read through a grip.
  dayUnder(x, y) {
    return document.elementsFromPoint(x, y)
                   .find((element) => element.dataset?.slot === "event-calendar-day")
                   ?.dataset?.day
  }
```

- [ ] **Step 4: Run the tests**

Run: `bundle exec rspec spec/system/event_calendar_spec.rb -e "moving an event"`
Expected: PASS.

- [ ] **Step 5: Run everything and commit**

```bash
bundle exec rake && bin/rubocop && bin/eslint
git add app spec
git commit -m "Move an event with a pointer, by a grip rather than the bar"
```

---

### Task 6: say what happened

A move is silent to a screen reader: the agenda's `aria-live` announces the
day's list changing, which is a side effect and not a message.

**Files:**
- Modify: `app/components/shadcn/event_calendar/component.rb` — the i18n keys
  and the value that crosses them
- Modify: `config/locales/en.yml` (the only locale the gem ships)
- Modify: `app/javascript/shadcn/controllers/event_calendar_controller.js`
- Test: `spec/system/event_calendar_spec.rb`

**Interfaces:**
- Consumes: `moveEvent`, `agendaKeydown`, `cancelPick`.
- Produces: `announce(message)` writing into the existing status region.

- [ ] **Step 1: Write the failing test**

```ruby
    it "says what it did, for a reader that cannot see it", :aggregate_failures do
      row("e5").send_keys(:space)
      expect(find("#{calendar} [role=status]", visible: :all).text).to include("Standup")

      press(:arrow_right)
      press(:space)

      expect(find("#{calendar} [role=status]", visible: :all).text).to include("August 21")
    end
```

- [ ] **Step 2: Run it and watch it fail**

Run: `bundle exec rspec spec/system/event_calendar_spec.rb -e "for a reader"`
Expected: FAIL — the region still holds the month.

- [ ] **Step 3: Add the strings and cross them**

In `config/locales/en.yml`, under the calendar's own keys:

```yaml
      picked: "%{title} picked. Use the arrow keys to choose a day, then Space."
      moved: "%{title} moved to %{date}."
      returned: "%{title} put back on %{date}."
```

Cross them as one value — the controller has no text of its own:

```ruby
          "data-shadcn--event-calendar-move-labels-value" => {
            picked: shadcn_t("event_calendar.picked", title: "%{title}"),
            moved: shadcn_t("event_calendar.moved", title: "%{title}", date: "%{date}"),
            returned: shadcn_t("event_calendar.returned", title: "%{title}", date: "%{date}")
          }.to_json,
```

- [ ] **Step 4: Announce**

```js
  announce(key, event, day) {
    const region = this.element.querySelector("[role='status']")
    if (!region) return

    region.textContent = (this.moveLabelsValue[key] || "")
      .replace("%{title}", event.title)
      .replace("%{date}", day ? this.format(parse(day), this.agendaFormatValue) : "")
  }
```

Call it from `agendaKeydown` (`picked`), from `moveEvent` (`moved`) and from the
`revert` closure (`returned`).

- [ ] **Step 5: Run and commit**

```bash
bundle exec rake && bin/rubocop && bin/eslint
git add app config spec
git commit -m "Say a move out loud, where only the day's list used to change"
```

---

### Task 7: write down what it is and what it is not

**Files:**
- Modify: `.claude/docs/features/event-calendar.md`
- Modify: `.claude/docs/todo.md`
- Modify: `.claude/docs/decisions/02-javascript.md`

- [ ] **Step 1: Replace the *Not done* entry**

Drag-to-move is done; resize is not. Rewrite the bullet to cover resize alone,
and move what the spike found into a section of its own: the two hands and why
they are two gestures, `movable:` and the `CustomEvent`, the value as the source
of truth, and the four holes — the invisible drop past `max_events`, the morph
resetting the selection, touch at `sm` and above unmeasured, the grip under
24×24 and the argument for it.

- [ ] **Step 2: Note the ordering that made the value the truth**

In `02-javascript.md`, under *Controllers re-sync on `turbo:morph`*: a
controller that mutates its own copy of a value puts itself out of a morph's
reach, because a morph reconciles the DOM and Stimulus fires a value callback
only on a change. Name the case: a refusal re-sends the payload the page already
had.

- [ ] **Step 3: Close the TODO entries**

In `todo.md`, drag-to-move comes out of *Deliberately not doing* — resize stays,
with the note that its machinery now exists.

- [ ] **Step 4: Commit**

```bash
git add .claude/docs
git commit -m "Write down what moving an event is, and the four things it is not"
```

---

## Self-review notes

- **Spec coverage.** Move-only and events-reading-only → Task 1's constraint and
  the Global Constraints. Two hands → Tasks 4 and 5. Value as truth → Task 4.
  `movable:` and the `CustomEvent` → Tasks 1 and 3. Identity → Task 1. `Item`
  prerequisite → Task 2. Pending → Tasks 3 and 4. Announcements → Task 6. The
  four holes → Task 7. Testing section → each task's own steps.
- **The one thing this plan adds to the spec:** the render-time `ArgumentError`
  for a movable event without an id, which the spec now carries too.
- **Names used across tasks:** `movable?` / `movableValue`, `data-event-id`,
  `moveEvent(id, shift, focusOn)`, `redrawAt(day)`, `dayUnder(x, y)`,
  `pickedEvent`, `announce(key, event, day)`. Task 5 calls Task 4's `moveEvent`
  with the same three arguments it defines.
