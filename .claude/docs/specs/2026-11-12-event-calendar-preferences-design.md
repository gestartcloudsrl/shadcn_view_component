# Event calendar: a person's preferred view

**Status:** agreed, 2026-11-12.

**Amended, 2026-11-12 (after Gestart's integration):** the `show_all` question
is replaced by a chip limit, `max_chips` (`3`, `5`, `all`), and the workload
reading takes `max_chips:`. Where this document says `show_all` for the dialog
or the posted fields, read `max_chips`; the toolbar's *Show all* toggle is
unchanged. Amended again the same day: the limit is typed, a number field
(1 to 99, `Preferences::MAX_CHIPS_RANGE`) beside an *All* radio, so it is left
out of the enumerated sets and the `:local` URL map carries it as a template.
The feature doc is the current reference. Feeds an implementation plan; not itself a plan.

**The question:** a person reaches the calendar from the same link every time
and wants it the way they left it: always *Weekly · Rows*, say. Today every
arrival draws the host's default and the panel has to be walked again. They
should be able to say once, in a modal, which view the calendar opens on.

## Why

The panel answers "show me this now". Nothing answers "show me this every
time". In Gestart a person arrives from the "Calendario" menu entry, never
from a link that names a view, and there is no case where a view must be
forced on them regardless of their preference.

The gem is published, so where the preference is kept cannot be Gestart's
answer alone: a host with a database keeps it there, and a host without one
still gets the feature from the browser.

## What a person sees

### The item

The options panel (the `settings-2` icon trigger) gets one more item at the
bottom, under a separator: **Preferences**, with an icon. It is an action,
not a radio item: it opens a modal and changes nothing by itself.

### The modal

A `Dialog`, titled *Preferences*, asking the panel's own questions, in the
panel's order:

| question | values | asked when |
|---|---|---|
| period | Monthly · Weekly · Daily | always |
| show the month as | Grid · Rows · Timeline | period is Monthly |
| show the week as | Rows · Timeline | period is Weekly |
| show the day as | Timeline · List · Timeline and list | period is Daily; *List* only if the day has an agenda to show *(Claude's call: `showing: :agenda` without one draws nothing, so saving it would save an empty view)* |
| group by | By event · By assignee | the chosen view groups (grid, rows, day) |
| show each job as | the host's `shapes:` | the chosen view has an axis and `shapes:` offers more than one |
| show all | on · off | the chosen view caps chips (grid, rows) *(Claude's call: this is the toolbar toggle beside the panel, not a panel question, but it is a way of looking a person may want every time)* |

- Every answer **starts at what the calendar is showing now**. Agreed in the
  conversation: the modal is "the panel's questions, answered for next time",
  not a checklist of what to remember.
- Changing the period re-asks the questions under it, as the panel does: only
  the ones that apply to the chosen view are on screen.
- **Save** stores the answers and **takes the calendar there at once** (agreed).
  **Cancel** and Escape close it and change nothing.

### Coming back

From the same link, the calendar opens on the saved view. The month shown and
the day selected are not part of it: the calendar opens on today, as it does
now.

## Decisions

Taken in the conversation:

- **The developer decides where preferences live, not the person.** Database
  or browser is a property of the host, not a setting in the modal.
- **The browser's `localStorage` is the gem's own fallback**, for a host that
  does not keep them. A host that keeps them gets the modal as a plain form
  posted to its own URL, saved by its own controller (agreed after review:
  "saved to the database through Turbo", without the gem naming Turbo).
- The modal asks the panel's questions, starting from the current values.
- Save applies the chosen view immediately.
- Arrivals always come from one link; no view is ever forced over a
  preference.

Proposed by Claude and accepted:

- **The API.** Off unless the host turns it on, because it adds a menu item, a
  modal and browser storage to a page that did not ask for them.
  - `preferences:` — `:local` (the gem keeps them in `localStorage`) or
    `:host` (the modal posts them to the host). Absent, there is no
    Preferences item. In the conversation this was "the host passes
    `preferences:` or not"; a symbol rather than a hash because the gem never
    needs the stored values: the modal starts from what is on screen, and in
    `:host` mode the host has already rendered from them.
  - `preferences_url:` (`:local` only) — given one complete set of
    preferences (`{ period:, view:, group:, shape:, showing:, show_all: }`,
    only the keys that apply), the URL that draws it. This is what Save
    navigates to, and what the browser navigates to when it restores. It is
    the existing `*_url:` idea taking every dimension at once, because a
    restore has to land on a combination in one step.
  - `preferences_save_url:` (`:host` only) — where the modal's form goes.
- **The URLs are computed on the server, all of them** (`:local` only). The browser cannot
  run the host's Ruby, and the valid combinations are few (about thirty: the
  views above crossed with the questions each one asks). The gem calls
  `preferences_url:` for each and ships the map in the markup, only when
  `preferences:` is on. No URL templates with placeholders: a host's lambda
  that looks a value up (`VIEWS.fetch(view)`) would break on a placeholder.
- **`:host` mode is a form** (agreed after review, replacing a JS event with
  a `persist(promise)`). The modal is a `<form method="post">` to
  `preferences_save_url:`, `_method=patch`, built with the gem's own form
  builder so the authenticity token is in it, fields named
  `preferences[period]`, `preferences[view]`, `preferences[group]`,
  `preferences[shape]`, `preferences[showing]`, `preferences[show_all]`
  (only those the chosen view asks; the rest are not sent). The host saves
  and redirects to the calendar (`status: :see_other`), and renders it from
  what it saved. Under Turbo Drive that is a fetch and a followed redirect;
  without it, an ordinary submit. Either way "Save takes you there at once"
  is the host's redirect, and failure is answered as the host answers any
  form (flash, or 422 and the page again). The earlier objection to a
  gem-owned save, that the token, the record and the response are the
  host's, does not hold for a plain form: all three stay the host's.
  Gestart's side, for the record:

  ```ruby
  def update
    current_user.update!(calendar_preferences: params.expect(preferences: %i[period view group shape showing show_all]))
    redirect_to calendar_path, status: :see_other
  end
  ```
- **Restoring in `:local` mode is signalled by the host** with `restore:`
  (agreed after review). Only the host knows that a request is the bare
  arrival, the usual link with no view named; for Gestart that is
  `restore: params[:period].blank?`. With `restore: true` and a stored set that
  differs from what was drawn, the controller goes there on connect with
  `location.replace(url)`. Without it, the controller never moves the page.
  The gem guessing instead (marking its own clicks in `sessionStorage`) was
  rejected: `connect` also fires on back/forward, when a host swaps the
  calendar after `month-change`, and after a host navigates in answer to a
  dispatched panel event, and each of those would have been pulled away from
  what the person had just chosen. The cost, said plainly: one line for the
  host, and on a bare arrival the default view shows for a moment before the
  saved one loads. `restore:` means nothing in `:host` mode, where the host
  has already rendered from its own stored set.
- **`localStorage` key** is `shadcn--event-calendar:preferences:<id>`, with
  the root's `id` when the host gives one and `default` otherwise, so two
  calendars in one app can be told apart by giving them ids.
- **The item's icon** is lucide's `user-cog`, to be added to
  `vendor/lucide/icons` and bundled with `rake icons:build` as `settings-2`
  was: the trigger is already a gear, and this is the person's own.
- **Each mode's URL is required,** `preferences_url:` for `:local` and
  `preferences_save_url:` for `:host`, and its absence raises at render time,
  as `movable:` without ids does. The gem cannot draw a stored set itself: *Monthly · Grid*, *Rows* and
  *Timeline* are different readings, and only the host's mapping turns a set
  into one. The panel is left as the host configured it, links or events.
- **Only readings with a panel get the item:** workload, the timelines, the
  week's rows, the day. On `reading: :auto`, which has no panel,
  `preferences:` is namespaced and ignored like every other reading keyword.
- **Turbo is not mentioned.** `location.replace`, a plain form and plain
  navigation, as the rest of the gem. Turbo, where the host has it, improves
  the form without the gem asking.

## Left to the builder

- The modal's controls: radio groups like the panel's, or `Select`s if the
  dialog gets too tall on a phone. Either way the gem's own components.
- How the controller and the dialog talk (the dialog's own controller, an
  outlet, or events), within the rules in
  `.claude/docs/decisions/02-javascript.md`.
- Where `:local`'s URL map lives in the markup (a `data-*` value or a JSON
  `<script type="application/json">`), and its size budget.
- How the dialog's form posts the right subset when the period changes
  (disabled fields are not submitted, which may be enough).
- Copy and i18n keys, English in the gem, Italian in the dummy app.
- A Lookbook preview for each mode, so snapshot and accessibility specs cover
  the modal open and closed.
- System specs: `:local` Save navigates and stores; `restore: true` with a
  stored set restores; `restore: false` never moves the page; `:host` submits
  the form with the token and the chosen fields (the dummy app gets a small
  controller and route that records and redirects).
- Docs: the feature doc's Options reference and a section of its own.

## Not in this design

- Saving the month or the selected day.
- A "reset to defaults" button. Saving other answers replaces the set.
- `window:` and `max_events:` in the modal. They are the developer's.
- Syncing `:local` preferences across devices. That is what `:host` is for.
- Changing what the panel does. A choice made there is for now, not for next
  time, and does not touch the saved set.
