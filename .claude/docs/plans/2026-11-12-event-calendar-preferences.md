# Event calendar preferences — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** a *Preferences* item in the options panel opens a modal with the
panel's questions; saving keeps the answers (in `localStorage`, or posted to the
host) and takes the calendar there, and a bare arrival opens on them.

**Architecture:** one plain object, `EventCalendar::Preferences`, owns the
questions: which apply to which view, every valid complete set, and the key a
set is known by. The component asks it for the form and, in `:local` mode, for
the URL of every set, which it ships to the controller. The controller only
toggles fields, writes `localStorage` and navigates. In `:host` mode the modal
is a plain form and no JavaScript saves anything.

**Tech Stack:** Ruby / ViewComponent, Stimulus, RSpec + Capybara + headless
Chrome. The gem's `Dialog`, `DropdownMenu::Item`, `shadcn_form_with` and its
`shadcn_radio_group`.

**Spec:** [`.claude/docs/specs/2026-11-12-event-calendar-preferences-design.md`](../specs/2026-11-12-event-calendar-preferences-design.md)
— read it first. Its *Decisions* are binding; *Left to the builder* is settled
below where a task needs it.

## Global Constraints

- **Off unless asked.** No `preferences:` → no item, no dialog, no `data-*`
  value, no URL map. Every existing golden in `spec/fixtures/snapshots/` must
  be byte-identical after Tasks 1–3 (only new previews add goldens).
- **`preferences:` is `:local` or `:host`.** Anything else is off.
  `:local` without `preferences_url:`, or `:host` without
  `preferences_save_url:`, raises `ArgumentError` at `new`, naming the missing
  keyword, as `movable:` without ids does (`component.rb`, `require_identities!`).
- **Only readings with a panel** draw the item: `Workload` (and `WeeklyRows`),
  `Hours` (and `Weekly`, `Daily`). On `reading: :auto` the keywords are
  consumed and ignored; they must not appear on the root as attributes.
- **The gem never names Turbo.** `location.replace`, a plain `<form>`.
- **Never split a class string across a `\` line continuation.**
- **New classes need a `reverse_parity_spec` `ours` entry with a reason**;
  that spec reads the goldens, so regenerate them first
  (`SNAPSHOTS=overwrite bundle exec rspec spec/snapshot_spec.rb`).
- **Icons:** `user-cog.svg` goes in `vendor/lucide/icons/`, taken from the
  `lucide-static` package at the version the other files' header names
  (v1.31.0). Fetching it is a download: ask the user before running it. Then
  `bundle exec rake icons:build`, and the README's bundled-icon count goes up by
  one (`icons_spec` checks it).
- **Copy:** English in `config/locales/en.yml`, Italian in
  `test/dummy/config/locales/it.yml`. Code and comments in English.
- Full check: `bundle exec rake`, `bin/rubocop`, `bin/eslint`. Commits on
  `feature/event-calendar`, English messages, no push.

## Review Focus

1. **A stored set the host no longer offers** (`shapes:` narrowed after a
   person saved `bars`; `agenda: false` after they saved `showing: :agenda`).
   Restore must not navigate to a URL that is not in the map; it does nothing.
   Pinned in Task 3.
2. **`localStorage` throws or is empty** (private window, blocked storage).
   Save still navigates; restore does nothing; no console error escapes.
   Pinned in Task 3.
3. **Two calendars on one page, or one per page with different ids.** The key
   uses the root `id`; a calendar without one uses `default`. Pinned in Task 3.
4. **Changing the period in the modal leaves a checked radio that no longer
   applies** (Grid checked, period switched to Weekly). The first applicable
   value is checked instead, and a disabled field is never posted. Pinned in
   Task 3.
5. **Restoring onto the set already drawn** must not reload in a loop.
   Pinned in Task 3.

---

### Task 1: `Preferences`, and `shapes:` read by every reading

**Files:**
- Create: `app/components/shadcn/event_calendar/preferences.rb`
- Modify: `app/components/shadcn/event_calendar/component.rb` (`SHAPES`,
  `shapes:` keyword, `READING_KEYWORDS`),
  `app/components/shadcn/event_calendar/hours/component.rb` (drop its own
  `shapes:` handling, read the base's)
- Test: `spec/components/shadcn/event_calendar_preferences_spec.rb` (new),
  `spec/components/shadcn/event_calendar_spec.rb` (the *a host offering one
  shape* block)

**Why `shapes:` moves:** the modal on a *month grid* must know whether to ask
the shape for *Monthly · Timeline*. Today `shapes:` is consumed by `Hours` only
and is a namespaced attribute everywhere else.

**Interfaces:**
- Produces, in `EventCalendar::Component`:
  - `SHAPES = %i[chips bars].freeze` (moved from `Hours`; `Hours::SHAPES`
    stays as an alias so `LANE_HEIGHTS.keys == SHAPES` can be asserted).
  - `initialize(..., shapes: SHAPES, ...)`, normalised as today (unknown names
    dropped, empty → all), reader `shapes`. `:shapes` leaves `READING_KEYWORDS`.
  - `Hours` keeps `shape:` and its fallback rule, reading `shapes` from `super`.
- Produces, `Shadcn::EventCalendar::Preferences`:
  - `QUESTIONS = %i[period view showing group shape show_all].freeze`, the form
    order and the key order.
  - `Preferences.new(shapes:, agenda:)`
  - `#sets -> Array<Hash{Symbol=>Symbol|Boolean}>` — every valid complete set,
    keys in `QUESTIONS` order, only those that apply.
  - `#normalize(Hash) -> Hash` — the same shape as one of `#sets`, dropping
    keys that do not apply; `nil` if the period/view is not a valid one.
  - `#when(question, value = nil) -> Array<String>` — the context tokens a
    field (or, with `value`, one of its options) is shown in (see below).
  - `Preferences.key(set) -> String`:
    `set.map { |q, v| "preferences[#{q}]=#{v}" }.join("&")`, in `QUESTIONS`
    order. The controller rebuilds the same string from `FormData`.

**The rules** (from the spec's modal table and its Claude's calls):

| question | values | applies to (context tokens) |
|---|---|---|
| `period` | `monthly weekly daily` | always |
| `view` | `grid rows hours` for `monthly`; `rows hours` for `weekly` | `monthly`, `weekly` |
| `showing` | `both axis`, plus `agenda` when `agenda:` | `daily` |
| `group` | `events assignees` | `monthly:grid monthly:rows weekly:rows daily` |
| `shape` | `shapes`, only when `shapes.size > 1` | `monthly:hours weekly:hours daily:both daily:axis` |
| `show_all` | `false true` | `monthly:grid monthly:rows weekly:rows` |

A context is `[period, "#{period}:#{second}"]`, where `second` is `view`, or
`showing` for `daily`. A field applies when one of its tokens is in the
context. The `view` options carry their own tokens (`grid` → `monthly`,
`rows`/`hours` → `monthly weekly`). Default values, used to order
`#sets` and as first choices: the first of each list.

- [ ] **Step 1: Write the failing spec** `event_calendar_preferences_spec.rb`:

```ruby
RSpec.describe Shadcn::EventCalendar::Preferences do
  subject(:preferences) { described_class.new(shapes: %i[chips bars], agenda: true) }

  it "asks each view only its own questions" do
    expect(preferences.sets).to include(
      { period: :monthly, view: :grid, group: :events, show_all: false },
      { period: :monthly, view: :hours, shape: :bars },
      { period: :weekly, view: :rows, group: :assignees, show_all: true },
      { period: :daily, showing: :agenda, group: :events },
      { period: :daily, showing: :axis, group: :events, shape: :chips }
    )
    expect(preferences.sets).not_to include(a_hash_including(period: :weekly, view: :grid))
  end

  it "counts every valid set once" do
    expect(preferences.sets.size).to eq(26)
    expect(preferences.sets.uniq.size).to eq(26)
  end

  it "stops asking the shape when one is offered, and the list without an agenda", :aggregate_failures do
    narrow = described_class.new(shapes: %i[chips], agenda: false)

    expect(narrow.sets).to all(satisfy { |set| !set.key?(:shape) })
    expect(narrow.sets.map { |set| set[:showing] }.compact.uniq).to eq(%i[both axis])
  end

  it "keys a set in question order" do
    expect(described_class.key({ period: :weekly, view: :rows, group: :events, show_all: false }))
      .to eq("preferences[period]=weekly&preferences[view]=rows&preferences[group]=events&preferences[show_all]=false")
  end

  it "normalises what a reading is drawing", :aggregate_failures do
    expect(preferences.normalize(period: :weekly, view: :rows, group: :events, show_all: false, shape: :bars))
      .to eq(period: :weekly, view: :rows, group: :events, show_all: false)
    expect(preferences.normalize(period: :weekly, view: :grid)).to be_nil
  end

  it "says where each field is shown" do
    expect(preferences.when(:shape)).to eq(%w[monthly:hours weekly:hours daily:both daily:axis])
    expect(preferences.when(:view, :grid)).to eq(%w[monthly])
  end
end
```

  26 = monthly grid 4 + rows 4 + hours 2, weekly rows 4 + hours 2, daily
  both 4 + axis 4 + agenda 2 — recount if a rule above changes, never the
  other way round.

- [ ] **Step 2: Run it, expect `NameError: uninitialized constant ...Preferences`.**
  `bundle exec rspec spec/components/shadcn/event_calendar_preferences_spec.rb`
- [ ] **Step 3: Implement `Preferences`** as a plain object (no
  ViewComponent), beside `schedule.rb`, with the table above as data.
- [ ] **Step 4: Move `shapes:` to the base.** Update the existing example
  *"is namespaced on a reading that has no shape"* to assert the root carries
  neither `shapes` nor `data-event-calendar-shapes` (it is consumed now), and
  rename it *"is consumed by a reading that has no shape"*.
- [ ] **Step 5: Run** both spec files, then `bundle exec rspec spec/snapshot_spec.rb`
  (goldens must not move). Expected: green.
- [ ] **Step 6: Commit** — "Name every view a person can prefer in one object".

### Task 2: The item, the dialog and the form, drawn by the server

**Files:**
- Modify: `app/components/shadcn/event_calendar/component.rb`,
  `workload/component.rb`, `hours/component.rb`, `daily/component.rb`
  (each reading's current values), `config/locales/en.yml`,
  `test/dummy/config/locales/it.yml`, `vendor/lucide/icons/user-cog.svg`
  (new, see Global Constraints), `lib/shadcn_view_component/icons.rb`
  (generated), `README.md` (icon count)
- Test: `spec/components/shadcn/event_calendar_spec.rb`

**Interfaces:**
- Consumes: `Preferences` from Task 1.
- Produces, on `EventCalendar::Component`:
  - `initialize(..., preferences: nil, preferences_url: nil, preferences_save_url: nil, restore: false, ...)`.
  - `preferences_mode -> :local | :host | nil` (public reader).
  - private `panel? -> Boolean` (false on the base, true in `Workload` and
    `Hours`), `preferences? = preferences_mode && panel?`.
  - private `preference_values -> Hash` per reading, the raw values:
    `Workload` `{ period:, view:, group:, show_all: }` (`WeeklyRows` inherits
    with `period: :weekly`), `Hours`/`Weekly` `{ period:, view: :hours, shape: }`,
    `Daily` `{ period: :daily, showing:, group:, shape: }`. Normalised by
    `Preferences#normalize` before use.
- Produces, in the markup when `preferences?` (names the controller relies on):
  - root `data-shadcn--event-calendar-preferences-value="local|host"`,
    `...-preferences-current-value` (the current set's key),
    `...-preferences-storage-value` (`"shadcn--event-calendar:preferences:#{id || 'default'}"`),
    and in `:local` only `...-preferences-restore-value` (`true|false`) and
    `...-preferences-urls-value` (JSON object, key → URL, one entry per
    `Preferences#sets`, each URL from `preferences_url.call(set)`).
  - In the panel, after a `DropdownMenu::Separator`, a
    `DropdownMenu::Item` with the `user-cog` icon and
    `event_calendar.preferences.item`, `data-action="click->shadcn--event-calendar#openPreferences"`.
  - A `Dialog::Component` beside the panel in the nav, its root a target
    `data-shadcn--event-calendar-target="preferencesDialog"`, no trigger slot
    (the item opens it). Header: title `preferences.title`, description
    `preferences.description`.
  - Inside it, `shadcn_form_with(scope: :preferences, url:, method:)`:
    `:host` → `url: preferences_save_url, method: :patch`; `:local` →
    `url: "#"`, `method: :post`, plus
    `data-action="submit->shadcn--event-calendar#savePreferences"`. Target
    `preferencesForm`, and `data-action="change->shadcn--event-calendar#refinePreferences"`
    in both modes.
  - One `shadcn_radio_group` per question in `QUESTIONS` order, each wrapped
    in an element with `data-preferences-when="<tokens joined by space>"`
    (`Preferences#when(question)`), and each `view` option with its own
    `data-preferences-when`. The `view` field has two labels,
    `event_calendar.view.label` and `.week_label`, each with its own
    `data-preferences-when` (`monthly`, `weekly`). Fields that do not apply to
    the current set render `hidden` and `disabled`. `show_all` is a radio of
    `false`/`true` labelled `preferences.show_all_off`/`show_all_on` under
    `group.show_all`.
  - Footer: `Dialog::Close` (`preferences.cancel`, outline) and
    `f.shadcn_submit(shadcn_t("event_calendar.preferences.save"))`.
- New copy (`event_calendar.preferences.*`): `item: Preferences`,
  `title: Preferences`, `description: Open the calendar this way every time.`,
  `save: Save`, `cancel: Cancel`, `show_all_on: Every job`,
  `show_all_off: The first few`. Italian: `Preferenze`, `Preferenze`,
  `Apri il calendario sempre così.`, `Salva`, `Annulla`, `Tutti i lavori`,
  `I primi`. No error copy: in `:host` a failed save is answered by the
  host's own response, and `:local` cannot fail visibly (Review Focus 2).

- [ ] **Step 1: Write the failing examples** in a new
  `describe "preferences"` in `event_calendar_spec.rb`:
  - *"is off unless asked"*: `reading: :workload` with no `preferences:` →
    no `[data-slot=dialog]`, no root attribute matching `/preferences/`.
  - *"raises without the URL its mode needs"*: `preferences: :local` without
    `preferences_url:` and `preferences: :host` without
    `preferences_save_url:` → `ArgumentError` with `/preferences_url/`,
    `/preferences_save_url/`.
  - *"draws the item and a form starting from what is shown"* —
    `reading: :weekly, arrangement: :rows, group: :assignees,
    preferences: :host, preferences_save_url: "/prefs"`:
    the panel has an item with text `Preferences` and a `lucide-user-cog`
    svg; the form's `action` is `/prefs` with a hidden `_method=patch` and an
    `authenticity_token` field; the checked radios are
    `preferences[period]=weekly`, `preferences[view]=rows`,
    `preferences[group]=assignees`, `preferences[show_all]=false`; the
    `showing` and `shape` fields are `hidden` and `disabled`.
  - *"ships every set's URL in :local mode"* — `reading: :hours,
    preferences: :local, preferences_url: ->(set) { "/c?#{set.to_query}" },
    restore: true`: `JSON.parse(root["data-shadcn--event-calendar-preferences-urls-value"]).size == 26`,
    its value for the current key is `"/c?period=monthly&shape=chips&view=hours"`,
    `...-current-value` equals
    `"preferences[period]=monthly&preferences[view]=hours&preferences[shape]=chips"`,
    `...-restore-value == "true"`.
  - *"leaves the auto reading alone"* — `reading: :auto, preferences: :local,
    preferences_url: ->(_) { "/" }`: no dialog, and the root carries no
    `preferences`, `preferences_url`, `restore` attribute.
  - *"asks the shape only when more than one is offered"* — `shapes: [:chips]`
    → no `preferences[shape]` input anywhere in the form.
- [ ] **Step 2: Run, expect failures** (`unknown keyword: :preferences` is
  fine as the first). Note: `test/dummy` must have a CSRF-capable view
  context; if `form_authenticity_token` is unavailable under
  `render_inline`, assert the hidden `authenticity_token` input exists only in
  the system spec (Task 3) and say so in the commit.
- [ ] **Step 3: Add the icon** (ask before downloading), `rake icons:build`,
  README count.
- [ ] **Step 4: Implement** the keywords, validation, `preference_values` per
  reading, the item, the dialog and the form. The controller actions it names
  are added in Task 3; `stimulus_contract_spec` will fail until then — run it
  in Task 3, not here.
- [ ] **Step 5: Run** `bundle exec rspec spec/components/shadcn/event_calendar_spec.rb spec/components/shadcn/event_calendar_preferences_spec.rb spec/icons_spec.rb spec/snapshot_spec.rb`.
  Expected: green, goldens unchanged.
- [ ] **Step 6: Commit** — "Draw the calendar's preferences as a form in a dialog".

### Task 3: The controller, the previews and the browser

**Files:**
- Modify: `app/javascript/shadcn/controllers/event_calendar_controller.js`,
  `app/components/shadcn/event_calendar/preview.rb` (`density` params and a
  new `preferences` preview), `test/dummy/config/routes.rb`,
  `test/dummy/app/controllers/calendar_controller.rb`,
  `spec/reverse_parity_spec.rb`, goldens
- Test: `spec/system/event_calendar_spec.rb`, `spec/stimulus_contract_spec.rb`
  (must pass), `spec/system/accessibility_spec.rb` (picks up the new preview)

**Interfaces:**
- Consumes: the values, targets and actions named in Task 2.
- Produces, in the controller:
  - values `preferences: String`, `preferencesCurrent: String`,
    `preferencesStorage: String`, `preferencesRestore: Boolean`,
    `preferencesUrls: Object`; targets `preferencesDialog`, `preferencesForm`.
  - `openPreferences()` — the dialog's controller via
    `this.application.getControllerForElementAndIdentifier(this.preferencesDialogTarget, "shadcn--dialog").open()`
    (the precedent is `drawer_controller.js:263`), then `refinePreferences()`.
  - `refinePreferences()` — up to three passes: compute the context from the
    form's checked `period` and `view`/`showing`; for every
    `[data-preferences-when]` set `hidden` and every input inside `disabled`
    when none of its tokens is in the context; where a radio group's checked
    input is disabled, check its first enabled one.
  - `savePreferences(event)` (`:local` only) — `preventDefault`; key =
    `[...new FormData(form)].filter(([n]) => n.startsWith("preferences[")).map(([n, v]) => \`${n}=${v}\`).join("&")`;
    `localStorage.setItem(storage, key)` inside `try`; then
    `location.assign(urls[key])` when it exists, else close the dialog.
  - restore, first thing in `connect()`: when `preferencesValue === "local"`
    and `preferencesRestoreValue`, read the stored key (inside `try`); if it
    differs from `preferencesCurrentValue` and `preferencesUrlsValue[key]`
    exists, `location.replace` it. Otherwise nothing.
- Produces, in the dummy app: `patch "calendar/preferences" =>
  "calendar#save_preferences", as: :calendar_preferences`, storing
  `params.expect(preferences: %i[period view showing group shape show_all])`
  in `session[:calendar_preferences]` and redirecting (`:see_other`) to
  `get "calendar/preferences" => "calendar#preferences"`, which renders the
  saved hash as text (enough for a spec to read).
- Produces, in `Preview#density`: params `preferences: "off"` (`off|local|host`)
  and `restore: false`; `:local` passes
  `preferences_url: ->(set) { here.call(**set) }` (the set's keys are
  `density`'s own params), `:host` passes
  `preferences_save_url: "/calendar/preferences"`. A new
  `Preview#preferences` renders `density(period: "weekly", view: "rows",
  preferences: "local")`, so the snapshot and accessibility suites cover it
  with the dialog closed.

- [ ] **Step 1: Write the failing system examples**, in a new
  `describe "preferences"` (all against `density?…`):
  - *"opens from the panel on the current answers"* — open panel, click
    *Preferences*: the dialog is open; the checked period is `weekly`, view
    `rows`.
  - *"re-asks when the period changes"* — in the dialog choose *Monthly*:
    the month's view labels are visible, *Grid* is checked if the week's
    view was not available (Review Focus 4), `showing` is not visible;
    choose *Daily*: the view field is hidden and disabled.
  - *"saves to the browser and goes there at once"* (`:local`) — choose
    *Daily*, *List only*, Save: `current_url` has `period=daily` and
    `showing=agenda`; `localStorage` under
    `shadcn--event-calendar:preferences:default` equals the key.
  - *"opens on the saved view from a bare arrival"* — set the storage key to
    the weekly-rows key with JS, visit `density?preferences=local&restore=true`:
    `current_url` ends up with `period=weekly&view=rows` in it.
  - *"stays put without restore"* — same storage, `restore=false`: the URL
    still says `period=monthly`.
  - *"ignores a stored set the host no longer offers"* — store a key with
    `preferences[shape]=bars`, render with `shapes` narrowed (add a
    `shapes` param to `density`, `"chips,bars"` default) to `chips` and
    `restore=true`: no navigation (Review Focus 1).
  - *"does not loop on the set already drawn"* — store the current key,
    `restore=true`: one visit, the URL unchanged after
    `Capybara.default_max_wait_time` (Review Focus 5).
  - *"survives a browser that refuses storage"* — stub
    `Storage.prototype.setItem`/`getItem` to throw before acting: Save still
    navigates, restore does nothing, `page.driver.browser.logs` has no error
    from the controller (Review Focus 2).
  - *"keys by the calendar's id"* — with `id: "crew"` on the component (add an
    `id` param to `density`), Save writes under
    `shadcn--event-calendar:preferences:crew` (Review Focus 3).
  - *"posts to the host"* (`:host`) — choose *Daily*, Save: the page at
    `/calendar/preferences` shows `period` `daily` and has no `view` key.
- [ ] **Step 2: Run, expect failures** (`Unknown action openPreferences` or
  the item click doing nothing).
- [ ] **Step 3: Implement** the controller, the dummy route and controller,
  and the preview params.
- [ ] **Step 4: Regenerate goldens**, then fix `reverse_parity_spec` `ours`
  with a reason per new class. Only `event_calendar-preferences.html` may be
  new; every other golden must be unchanged (`git status spec/fixtures`).
- [ ] **Step 5: Run** `bundle exec rspec spec/system/event_calendar_spec.rb -e preferences`,
  then `bundle exec rake`, `bin/rubocop`, `bin/eslint`. Expected: green.
- [ ] **Step 6: Docs.** In `.claude/docs/features/event-calendar.md`: the
  *Options* tables get `preferences:`, `preferences_url:`,
  `preferences_save_url:`, `restore:` and the moved `shapes:` (now every
  reading); a section *A person's preferred view* with the two modes, the
  host's controller (copy the spec's Gestart snippet), `restore:` and why the
  gem does not guess, the storage key, and what is not saved.
- [ ] **Step 7: Commit** — "Save and restore a person's preferred calendar view".
