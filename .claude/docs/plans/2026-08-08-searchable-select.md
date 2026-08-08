# Searchable Select Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `searchable:` to `Shadcn::Select::Component`, so an open select shows
a filter field above its options.

**Architecture:** This is **not a port.** No Radix component does this, so there
is nothing to be 1:1 with. What is taken from shadcn's React Aria variant is its
*shape* — a `role="dialog"` popover holding a search field and a separate
`role="listbox"` — plus the plain Tailwind utilities and `data-slot` names it
uses. What cannot be taken is its visual design, which lives in semantic `cn-*`
classes defined in style sheets this gem does not ship. The highlight becomes
virtual (`aria-activedescendant`) because focus has to stay in the field for
typing to work, and filtering hides options rather than removing them, since
they are server-rendered ERB.

**Tech Stack:** ViewComponent, `view_component-contrib` StyleVariants, Stimulus,
Capybara + headless Chrome, axe-rspec.

---

## Background — read all of this before Task 1

Three rounds of investigation stand behind this plan. Skipping them means
redoing them.

### The component exists in exactly one base, and it is not ours

`shadcn-ui/ui` now authors components as *bases* crossed with *styles*.
`grep -rl "select-input" apps/v4/registry/bases/*/ui/select.tsx` returns one
file: `bases/aria/ui/select.tsx`. Neither `bases/radix` nor `bases/base` has a
searchable select. This gem ports `new-york-v4`, which shadcn's own
`apps/v4/registry/README.md:16` calls "the legacy source registry".

Two things follow, and the second matters more than the first.

`new-york-v4` is **frozen, not abandoned**: it and `bases/radix` both hold 61
components, differing by one each way (`questionnaire` there, `form` here), and
`select.tsx`, `dropdown-menu.tsx`, `button.tsx` and `card.tsx` are byte-identical
between it and this gem's vendored copies. shadcn's changelog says plainly:
"Radix is not being deprecated. We still support it, and every update and new
component will ship for both libraries."

And **the searchable select is not something the legacy registry missed.** It
does not exist in Radix at all. That is why this is not a port: the rule
"upstream wins on markup" has no upstream to point at here.

### Only part of the aria source is usable

Its slots carry a mix. These are plain Tailwind and are taken verbatim:

| slot | upstream's utilities |
|---|---|
| `select-list` | `group/select-list max-h-[inherit] overflow-x-hidden overflow-y-auto p-0 outline-hidden` |
| `select-input-wrapper` | `p-1 pb-0` |

`select-empty` carries only `cn-select-empty-aria`, whose definition lives in
`registry/styles/style-*.css` — six-plus themed sheets of ~1700 lines each. That
one is designed here.

Upstream also composes `InputGroup` / `InputGroupInput` / `InputGroupAddon`, all
three of which this gem already ports, and stamps `data-slot="select-input"` onto
the `InputGroupInput`. **This port must not**: its own input-group raises the
focus ring with `has-[[data-slot=input-group-control]:focus-visible]:ring-[3px]`,
while the aria variant's `input-group.tsx` has no `has-[[data-slot=…]]` selector
at all and styles focus through `cn-*`. Restamping the control here switches the
ring off, visibly, with nothing to catch it. The control keeps
`input-group-control`, and `select-input` is not among the slots this component
adds.

### The ARIA shape was chosen by measurement, not argument

Four shapes were audited on this branch (commits `3e5722f`, `c224353`):

- **The popover must be `role="dialog"`.** Putting the search input inside our
  `SelectContent`, which carries `role="listbox"`, is a *critical* axe
  violation — `aria-required-children`: "Element has children which are not
  allowed: input[aria-controls]".
- **Upstream's trigger is a plain `<button>`** with `aria-haspopup="listbox"`
  and no `role`. All eight aria triggers on that page are role-less.
- **Upstream's search input has no accessible name** at all, and axe calls that
  a *critical* `label` violation. Naming it is a deliberate deviation.

## Global Constraints

- **`searchable:` defaults to `false`, and a non-searchable select must be
  unchanged** apart from the new `data-shadcn--select-searchable-value`
  attribute. Regenerate snapshots once, in Task 3, and read the diff.
- **This component is declared, not inferred.** Every `data-slot` it adds beyond
  upstream is listed in `parity_spec.rb` (Task 1) and explained in
  `decisions/01-architecture.md` (Task 1). Adding a slot later without adding it
  there fails Task 1's example.
- **No npm dependency.** The magnifier is inlined like every other icon.
- **Never split a class string across a `\` line continuation** — Tailwind scans
  source text, so half a token generates no CSS.
- **Attribute precedence is `data-slot` < component defaults < caller.** What a
  subclass passes to `super` in `#element_attributes` is a *default*.
- Run `bundle exec rake` and `bin/rubocop` before every commit. Both must be
  clean. Do not infer a suite result from a previous run.
- The gallery layout carries its own ThemeSelector, which is also a Select, so
  scope every system-spec lookup: `all("[data-slot=select]").last`.

---

## File Structure

**Created**

| File | Responsibility |
|---|---|
| `app/components/shadcn/select/list/component.rb` | `data-slot="select-list"`, `role="listbox"` — where the options live once a search field shares the popover |
| `app/components/shadcn/select/search/component.rb` | `data-slot="select-input-wrapper"` around the ported `InputGroup` |
| `app/components/shadcn/select/empty/component.rb` | `data-slot="select-empty"` — the one part whose look is ours |
| `app/components/shadcn/select/previews/searchable.html.erb` | the preview that puts this under the snapshot, preview and accessibility specs |

**Modified**

| File | Change |
|---|---|
| `spec/parity_spec.rb` | declares the slots this port adds beyond upstream |
| `app/components/shadcn/select/component.rb` | `searchable:`, its data value, lambda slots feeding trigger and content |
| `app/components/shadcn/select/content/component.rb` | `role="dialog"` when searchable; search + list + empty; viewport stops scrolling |
| `app/components/shadcn/select/trigger/component.rb` | drops `role="combobox"` for `aria-haspopup="listbox"` when searchable |
| `app/components/shadcn/icon/component.rb` | adds the `search` path |
| `app/javascript/shadcn/controllers/select_controller.js` | virtual focus, filtering, key handling, close behaviour |
| `app/components/shadcn/select/preview.rb` | registers `searchable`, drops the five spike previews |
| `spec/system/select_spec.rb`, `spec/system/accessibility_spec.rb` | a `when searchable` context, and one axe example |
| `config/locales/en.yml` | four strings |
| `README.md`, `.claude/docs/todo.md`, `.claude/docs/decisions/01-architecture.md` | Tasks 1 and 7 |

**Deleted** (Task 3): the five `spike_*.html.erb` previews, their `preview.rb`
methods, and `spec/system/select_searchable_spike_spec.rb`.

---

### Task 1: Declare the divergence before building it

**Files:**
- Modify: `spec/parity_spec.rb`, `.claude/docs/decisions/01-architecture.md`

**Interfaces:**
- Produces: `ours_alone` in `parity_spec.rb`, the list every later task must keep
  true.

`parity_spec` is **one-way**: `expected.reject { |klass| ported.include?(klass) }`
asserts upstream's classes are all present and says nothing about classes only we
have. So the four new slots are invisible to it and nothing breaks. That is
today. `todo.md` still carries a reverse-parity check "keyed on `data-slot`", and
the first thing such a check would report is exactly this component. Declaring it
now is what stops that from looking like a defect later.

- [ ] **Step 1: Write the failing example**

In `spec/parity_spec.rb`, after the `allowed_missing` constant:

```ruby
# `data-slot`s this port carries that no vendored TSX does. Parity is one-way —
# it asserts upstream's classes are present, never that ours are upstream's — so
# these are invisible to it. They are declared anyway: `todo.md` still wants a
# reverse-parity check keyed on `data-slot`, and this list is what it must not
# flag. The searchable select is deliberate divergence, not drift; the reasoning
# is in `decisions/01-architecture.md`.
ours_alone = {
  "select" => %w[select-input-wrapper select-list select-empty]
}.freeze

it "declares the slots this port adds beyond upstream" do
  ours_alone.each do |family, slots|
    source = Dir[Pathname(__dir__).join("../app/components/shadcn", family, "**/*.rb")]
             .map { |path| File.read(path) }.join

    slots.each do |slot|
      expect(source).to include(slot),
                        "#{family} declares #{slot} in parity_spec but no component emits it"
    end
  end
end
```

- [ ] **Step 2: Run it and watch it fail**

Run: `bundle exec rspec spec/parity_spec.rb -e "declares the slots"`
Expected: FAIL on `select-input-wrapper` — nothing emits it yet. That failure is the
point: the list cannot be written ahead of the components and then quietly rot.

Leave it failing. Tasks 2 and 3 are what make it pass; do not comment it out.

- [ ] **Step 3: Write the reasoning down**

In `.claude/docs/decisions/01-architecture.md`, after the `loop:` entry, a
section headed **A component that is ours, not a port**. It must say, in prose:

- The searchable select exists in exactly one shadcn base, `aria`, and in
  neither Radix base. This gem ports `new-york-v4`. So "1:1 with upstream" has no
  referent here, and the component is built rather than transcribed.
- `new-york-v4` is the *legacy* source registry by shadcn's own README, but it is
  frozen rather than abandoned — one component apart from `bases/radix`, and
  byte-identical for the four files checked. The gem is not porting something
  that is rotting.
- What was taken: the shape (dialog popover, separate listbox, virtual focus),
  the `data-slot` names, and the plain Tailwind utilities. What could not be
  taken: `cn-select-empty-aria`, whose definition lives in style sheets not
  shipped here.
- The three deviations, each with its reason: the search input gets an
  accessible name (upstream's has none, and axe calls that critical); the empty
  state sits outside the listbox (a non-option inside one is what axe rejected);
  `select-list` carries `p-1` where upstream has `p-0`, because this port's
  padding moved off the viewport.
- That `parity_spec`'s `ours_alone` is the machine-readable half of this section.

- [ ] **Step 4: Commit**

```sh
bin/rubocop
git add spec/parity_spec.rb .claude/docs/decisions/01-architecture.md
git commit -m "Declare the searchable select as deliberate divergence"
```

The suite is red at this point, on one example, by design. Say so in the commit
body.

---

### Task 2: Bundle the magnifier icon

**Files:**
- Modify: `app/components/shadcn/icon/component.rb`
- Test: `spec/components/shadcn/icon_spec.rb`

**Interfaces:**
- Produces: `Shadcn::Icon::Component.new("search")` renders without raising.

`PATHS` at `icon/component.rb:14` holds eleven icons. `search` is not among them,
and an unknown name **raises** where `Rails.env.local?` — which is why the first
draft of a spike preview failed to render at all rather than showing a gap.

- [ ] **Step 1: Write the failing test**

In `spec/components/shadcn/icon_spec.rb`, inside the existing describe:

```ruby
it "bundles the magnifier the searchable select needs" do
  render_inline(described_class.new("search"))

  expect(page).to have_css("svg circle[cx='11'][cy='11'][r='8']", visible: :all)
end
```

- [ ] **Step 2: Run it and watch it fail**

Run: `bundle exec rspec spec/components/shadcn/icon_spec.rb -e "magnifier"`
Expected: FAIL — an unknown icon name raises, so the error is the raise itself,
not a missing element.

- [ ] **Step 3: Add the path**

In the `PATHS` hash, in the same `%(...)` style as its neighbours:

```ruby
"search" => %(<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>),
```

That is lucide's `search`, which is what upstream's addon renders.

- [ ] **Step 4: Green**

Run: `bundle exec rspec spec/components/shadcn/icon_spec.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```sh
bin/rubocop
git add app/components/shadcn/icon spec/components/shadcn/icon_spec.rb
git commit -m "Bundle lucide's search icon"
```

---

### Task 3: The markup

**Files:**
- Create: `app/components/shadcn/select/list/component.rb`, `app/components/shadcn/select/search/component.rb`, `app/components/shadcn/select/empty/component.rb`, `app/components/shadcn/select/previews/searchable.html.erb`
- Modify: `app/components/shadcn/select/component.rb`, `app/components/shadcn/select/content/component.rb`, `app/components/shadcn/select/trigger/component.rb`, `app/components/shadcn/select/preview.rb`, `config/locales/en.yml`, `spec/system/accessibility_spec.rb`
- Delete: `app/components/shadcn/select/previews/spike_*.html.erb`, `spec/system/select_searchable_spike_spec.rb`
- Test: `spec/system/select_spec.rb`

**Interfaces:**
- Consumes: `Shadcn::Icon::Component.new("search")` from Task 2; the
  `ours_alone` list from Task 1.
- Produces: `Shadcn::Select::Component.new(searchable: true)`; the Stimulus
  targets `search`, `list` and `empty` that Tasks 4–6 drive.

None of the four new components is declared with the `part` macro. `part`
"declares a slot, classes and a tag, and no other attribute"
(`decisions/01-architecture.md`), and each of these carries more.

- [ ] **Step 1: Write the failing spec**

Add to `spec/system/select_spec.rb`, at the top level of the describe:

```ruby
context "when searchable" do
  before do
    visit_preview(:select, :searchable)
    wait_for_stimulus
    within(preview) { find(trigger).click }
    expect(page).to have_css(content)
  end

  it "opens a dialog holding a search field and a separate listbox" do
    within(preview) do
      expect(find(content)["role"]).to eq("dialog")
      expect(find("[data-slot=select-list]")["role"]).to eq("listbox")
      expect(page).to have_css("[data-slot=select-input]")
    end
  end

  it "gives the trigger a popup button's semantics rather than a combobox's" do
    within(preview) do
      expect(find(trigger)["role"]).to be_nil
      expect(find(trigger)["aria-haspopup"]).to eq("listbox")
    end
  end

  it "names the search field, which upstream leaves unnamed" do
    within(preview) do
      expect(find("[data-slot=select-input]")["aria-label"]).to be_present
    end
  end
end
```

- [ ] **Step 2: Run it and watch it fail**

Run: `bundle exec rspec spec/system/select_spec.rb -e "when searchable"`
Expected: FAIL — the preview does not exist, so `visit_preview` raises before any
assertion runs.

- [ ] **Step 3: Create `Select::List::Component`**

```ruby
# frozen_string_literal: true

module Shadcn
  module Select
    module List
      # Where the options live once a search field shares the popover. In the
      # plain select the listbox role sits on SelectContent itself; it cannot
      # when a text field is in there too, because a textbox is not an allowed
      # child of a listbox — axe reports `aria-required-children`, critical.
      #
      # Classes are shadcn's aria base verbatim except `p-1` for its `p-0`: our
      # padding moved off the viewport, which upstream keeps.
      class Component < ApplicationViewComponent
        slot_name :"select-list"

        style do
          base {
            "group/select-list max-h-[inherit] overflow-x-hidden overflow-y-auto p-1 outline-hidden"
          }
        end

        def element_attributes(**defaults)
          super(**{
            role: "listbox",
            "aria-label" => shadcn_t("select.list_label"),
            "data-shadcn--select-target" => "list"
          }.merge(defaults))
        end
      end
    end
  end
end
```

- [ ] **Step 4: Create `Select::Search::Component`**

One file, not two. Upstream restamps its `InputGroupInput` as
`data-slot="select-input"`; this port renders the ported component unchanged and
passes it attributes, because that slot name is load-bearing here — the group
raises its focus ring off `has-[[data-slot=input-group-control]:focus-visible]`,
and the aria variant has no such selector to break.

```ruby
# frozen_string_literal: true

module Shadcn
  module Select
    module Search
      # The filter field, composing the already-ported InputGroup the way
      # shadcn's aria variant does — its popover renders `data-slot="input-group"`
      # around the control, with the magnifier as an addon.
      class Component < ApplicationViewComponent
        slot_name :"select-input-wrapper"

        style do
          base { "p-1 pb-0" }
        end

        attr_reader :label

        def initialize(label: nil, **attributes)
          @label = label
          super(**attributes)
        end

        def call
          render_element(body: render(InputGroup::Component.new) { safe_join([ field, addon ]) })
        end

        private

        def field
          render(InputGroup::Input::Component.new(
                   "aria-label": label || shadcn_t("select.search_label"),
                   "aria-autocomplete": "list",
                   "data-shadcn--select-target": "search",
                   "data-action": "input->shadcn--select#search"
                 ))
        end

        def addon
          render(InputGroup::Addon::Component.new) do
            render(Icon::Component.new("search", class: "size-4"))
          end
        end
      end
    end
  end
end
```

- [ ] **Step 5: Create `Select::Empty::Component`**

This is the one part whose look is ours: upstream's is a single `cn-*` class
whose definition lives in style sheets this gem does not ship. The classes below
reuse tokens the design system already uses — `text-muted-foreground` is on
`select-label`.

```ruby
# frozen_string_literal: true

module Shadcn
  module Select
    module Empty
      # Shown when the filter matches nothing.
      #
      # A *sibling* of the listbox rather than a child. Upstream nests its empty
      # state inside the list with `role="option"` — an option that cannot be
      # chosen — which is how React Aria's collection renders it. Outside the
      # list the question does not arise, and a non-option inside a listbox is
      # the shape axe rejected.
      #
      # The classes are this gem's own: upstream's `cn-select-empty-aria` is
      # defined in `registry/styles/style-*.css`, which is not vendored here.
      class Component < ApplicationViewComponent
        slot_name :"select-empty"

        style do
          base { "py-6 text-center text-sm text-muted-foreground" }
        end

        def element_attributes(**defaults)
          super(**{
            hidden: true,
            "data-shadcn--select-target" => "empty"
          }.merge(defaults))
        end

        def call
          render_element(body: content.presence || shadcn_t("select.empty"))
        end
      end
    end
  end
end
```

- [ ] **Step 6: Add the four strings**

In `config/locales/en.yml`, under the existing `shadcn_view_component:` tree
(the helper is `shadcn_t`, defined at `application_view_component.rb:117`, which
prefixes `shadcn_view_component.`):

```yaml
    select:
      search_label: Search options
      empty: No results found.
      dialog_label: Select an option
      list_label: Options
```

`list_label` is not decoration: an unnamed `role="listbox"` is an
`aria-input-field-name` violation — serious, and WCAG rather than best-practice —
which is how it was found. The dialog is named separately so a screen reader
announces the popover and then the list rather than the same words twice.

- [ ] **Step 7: Thread `searchable` through the root**

In `app/components/shadcn/select/component.rb`, replace the two `renders_one`
lines. Lambda slots are how `ToggleGroup` already feeds group state to its
children (`toggle_group/component.rb:10`).

```ruby
renders_one :trigger, ->(**kwargs, &block) {
  Trigger::Component.new(searchable:, **kwargs, &block)
}
renders_one :select_content, ->(**kwargs, &block) {
  Content::Component.new(searchable:, **kwargs, &block)
}
```

Add `searchable` to `attr_reader`, `searchable: false` to the constructor
keywords, `@searchable = searchable` to its body, and to `element_attributes`:

```ruby
"data-shadcn--select-searchable-value" => searchable
```

- [ ] **Step 8: Make the trigger a plain button when searchable**

In `trigger/component.rb`, add `searchable: false` to the constructor and
`attr_reader`, then:

```ruby
role: ("combobox" unless searchable),
"aria-haspopup" => ("listbox" if searchable),
"aria-autocomplete" => ("none" unless searchable),
```

`role: nil` omits the attribute rather than emitting an empty one.

- [ ] **Step 9: Restructure the content when searchable**

In `content/component.rb`, add `searchable: false` to the constructor and
`attr_reader`. Then:

```ruby
def element_attributes(**defaults)
  super(**{
    role: (searchable ? "dialog" : "listbox"),
    "aria-label" => (shadcn_t("select.dialog_label") if searchable),
    # …the rest unchanged…
  }.merge(defaults))
end
```

```ruby
def viewport
  tag.div(searchable ? searchable_body : plain_body, class: viewport_classes)
end

def searchable_body
  safe_join([
    render(Search::Component.new),
    render(List::Component.new) { plain_body },
    render(Empty::Component.new)
  ])
end

def plain_body
  safe_join([ items, content ].flatten.compact)
end
```

and the viewport stops scrolling, because the list does instead:

```ruby
def viewport_classes
  return ShadcnViewComponent.cn("flex flex-col overflow-hidden") if searchable

  # …the existing popper/item-aligned body, unchanged…
end
```

- [ ] **Step 10: Write the preview and delete the spike**

`app/components/shadcn/select/previews/searchable.html.erb`:

```erb
<%= render(Shadcn::Select::Component.new(name: "fruit", placeholder: "Select a fruit", searchable: true)) do |s| %>
  <% s.with_trigger(class: "w-[220px]", "aria-label": "Favourite fruit") do |tr| %>
    <% tr.with_value(placeholder: "Select a fruit") %>
  <% end %>
  <% s.with_select_content do %>
    <%= render(Shadcn::Select::Item::Component.new(value: "apple")) { "Apple" } %>
    <%= render(Shadcn::Select::Item::Component.new(value: "banana")) { "Banana" } %>
    <%= render(Shadcn::Select::Item::Component.new(value: "blueberry")) { "Blueberry" } %>
    <%= render(Shadcn::Select::Item::Component.new(value: "grapes")) { "Grapes" } %>
    <%= render(Shadcn::Select::Item::Component.new(value: "pineapple")) { "Pineapple" } %>
  <% end %>
<% end %>
```

In `select/preview.rb`, add `searchable` and **delete the five spike methods** in
the same edit:

```ruby
def searchable
  render_with_template
end
```

```sh
rm app/components/shadcn/select/previews/spike_*.html.erb
rm spec/system/select_searchable_spike_spec.rb
```

- [ ] **Step 11: Green, then regenerate snapshots and read the diff**

Run: `bundle exec rspec spec/system/select_spec.rb -e "when searchable"`
Expected: PASS.

Run: `bundle exec rspec spec/parity_spec.rb -e "declares the slots"`
Expected: PASS now — Task 1's example was waiting for these four slots.

```sh
SNAPSHOTS=overwrite bundle exec rspec spec/snapshot_spec.rb
git diff --stat spec/fixtures/snapshots/
```

Expected: `select-searchable.html` added, the five `select-spike_*.html` files
removed, and the two remaining changed files — the select's own and
`theme_selector`'s, which is also a Select — differing **only** by
`data-shadcn--select-searchable-value="false"`. Anything else means the default
path moved when it was not supposed to.

- [ ] **Step 12: Audit it**

`accessibility_spec.rb` audits `default.html.erb` per family, so it will not see
this preview. Add one example beside the existing `with the select open`
context:

```ruby
context "with a searchable select open" do
  it "has no violations" do
    visit_preview(:select, :searchable)
    wait_for_stimulus
    within(all("[data-slot=select]").last) { find("[data-slot=select-trigger]").click }
    expect(page).to have_css("[data-slot=select-content]")

    audit
  end
end
```

Run: `bundle exec rspec spec/system/accessibility_spec.rb -e "searchable"`
Expected: PASS. A `label` violation means the search field lost its
`aria-label`; `aria-required-children` means items ended up outside
`select-list`.

- [ ] **Step 13: Commit, with four known failures**

`stimulus_contract_spec` couples the two sides: the markup written here names a
`searchable` value, `list` and `empty` targets and a `search` action that the
controller does not have until Tasks 4 and 5. Expect exactly four failures there
and nowhere else, and say so in the commit body. Do not silence them by writing
controller code ahead of the specs that drive it.

```sh
bundle exec rspec spec/stimulus_contract_spec.rb   # expect 4 failures, all shadcn--select
bin/rubocop
git add -A app/components/shadcn/select config/locales spec
git commit -m "Render the searchable select's markup"
```

Task 4 closes the `searchable` value and the `list`/`empty` targets; Task 5
closes the `search` action.

---

### Task 4: Virtual focus

**Files:**
- Modify: `app/javascript/shadcn/controllers/select_controller.js`
- Test: `spec/system/select_spec.rb`

**Interfaces:**
- Consumes: the `search`, `list` and `empty` targets from Task 3.
- Produces: `highlight()` honouring `searchableValue`; every item carrying a
  generated `id`.

`highlight()` currently calls `item.focus()`. In a searchable select that pulls
focus out of the field on the first arrow key and typing stops working. Upstream
keeps DOM focus on the input and points `aria-activedescendant` at the active
option.

- [ ] **Step 1: Write the failing spec**

Inside the `when searchable` context:

```ruby
it "moves the highlight with the arrows while focus stays in the search field" do
  press(:arrow_down)

  expect(highlighted).to eq("banana")
  expect(page.evaluate_script("document.activeElement.dataset.slot")).to eq("select-input")
  expect(page.evaluate_script(<<~JS)).to eq(true)
    (() => {
      const input = document.querySelector("[data-slot=select-input]")
      const id = input.getAttribute("aria-activedescendant")
      return !!id && document.getElementById(id).dataset.value === "banana"
    })()
  JS
end
```

`banana` and not `apple` because `onOpen` already highlights the first item, so
the first ArrowDown is a move off it. `highlighted` is the method already at the
top of `select_spec.rb`; it reads `[data-highlighted]`, which is unaffected —
only what focus does changes.

- [ ] **Step 2: Run it and watch it fail**

Run: `bundle exec rspec spec/system/select_spec.rb -e "focus stays in the search field"`
Expected: FAIL on the `activeElement` assertion, reporting `select-item` — the
old `item.focus()` firing.

- [ ] **Step 3: Add the value and the targets**

```js
static targets = [ "trigger", "content", "item", "value", "input", "search", "list", "empty" ]
static values = {
  // …existing…
  searchable: Boolean
}
```

`input` is already the hidden form field, which is why the text field is
`search`.

- [ ] **Step 4: Give the items ids and wire the field at connect**

In `connect()`, after the existing `this.contentTarget.id ||= …`:

```js
if (this.searchableValue && this.hasSearchTarget && this.hasListTarget) {
  this.listTarget.id ||= uniqueId("shadcn-select-list")
  this.searchTarget.setAttribute("aria-controls", this.listTarget.id)
  this.itemTargets.forEach((item) => (item.id ||= uniqueId("shadcn-select-item")))
}
```

Generated here for the same reason the content's id is: the server cannot know
them, and `crypto.randomUUID()` is secure-context only — which is what
`uniqueId` exists to avoid.

- [ ] **Step 5: Branch `highlight` and `clearHighlight`**

```js
highlight(item) {
  this.clearHighlight()
  if (!item) return

  item.dataset.highlighted = ""

  if (this.searchableValue) {
    // Focus stays in the field, or typing stops.
    this.searchTarget.setAttribute("aria-activedescendant", item.id)
  } else {
    item.focus({ preventScroll: true })
  }

  item.scrollIntoView({ block: "nearest" })
}

clearHighlight() {
  this.itemTargets.forEach((item) => delete item.dataset.highlighted)
  if (this.searchableValue && this.hasSearchTarget) {
    this.searchTarget.removeAttribute("aria-activedescendant")
  }
}
```

- [ ] **Step 6: Focus the field rather than the content on open**

In the `onOpen` callback, replacing the single `this.contentTarget.focus(...)`
line and leaving `this.typeahead.reset()` and the `highlight` call where they
are:

```js
if (this.searchableValue && this.hasSearchTarget) {
  this.searchTarget.focus({ preventScroll: true })
} else {
  this.contentTarget.focus({ preventScroll: true })
}
```

- [ ] **Step 7: Green, then verify by mutation**

Run: `bundle exec rspec spec/system/select_spec.rb`
Expected: PASS, every pre-existing example included — the plain path must be
untouched.

Run: `bundle exec rspec spec/stimulus_contract_spec.rb`
Expected: down from four failures to one — only the `search` action is left, and
Task 5 writes it.

Then break it: change the test in `highlight` to `false && this.searchableValue`,
re-run the new example, confirm it fails on the `activeElement` assertion,
restore, and confirm `git diff` shows only the intended change. A spec that
cannot be broken this way is not testing the branch.

- [ ] **Step 8: Commit**

```sh
bundle exec rake && bin/rubocop
git add app/javascript/shadcn/controllers/select_controller.js spec/system/select_spec.rb
git commit -m "Move the searchable select's highlight to aria-activedescendant"
```

---

### Task 5: Filtering

**Files:**
- Modify: `app/javascript/shadcn/controllers/select_controller.js`
- Test: `spec/system/select_spec.rb`

**Interfaces:**
- Consumes: the targets and `searchableValue` from Task 4.
- Produces: a `search()` action, already referenced by the
  `input->shadcn--select#search` action Task 3 put on the field; `enabledItems`
  excluding filtered-out items.

Upstream filters case-insensitively on **substring**, not prefix — typing `gent`
reaches Argentina — and removes non-matching options from the DOM. This hides
them instead: the options are server-rendered ERB, and one removed cannot be put
back.

- [ ] **Step 1: Write the failing specs**

```ruby
it "narrows the list to substring matches, not just prefixes" do
  fill_in_search("err")

  expect(visible_item_values).to eq(%w[blueberry])
end

it "shows the empty state when nothing matches, and hides the list" do
  fill_in_search("zzz")

  within(preview) do
    expect(page).to have_css("[data-slot=select-empty]", visible: true)
    expect(page).to have_no_css("[data-slot=select-list]", visible: true)
  end
end

it "keeps the arrow keys inside what is left after filtering" do
  fill_in_search("p")
  press(:arrow_down)

  # apple, grapes and pineapple survive "p"; the highlight starts on the first
  # of them, so one ArrowDown reaches the second.
  expect(highlighted).to eq("grapes")
end
```

with two helpers beside the existing `highlighted`. Both are methods rather than
`let` because each is read after a keystroke has changed the DOM, and `let`
memoises.

```ruby
def fill_in_search(query)
  within(preview) { find("[data-slot=select-input]").set(query) }
end

def visible_item_values
  page.evaluate_script(<<~JS)
    [...document.querySelectorAll("[data-slot=select-item]")]
      .filter((item) => !item.hidden)
      .map((item) => item.dataset.value)
  JS
end
```

- [ ] **Step 2: Run them and watch them fail**

Run: `bundle exec rspec spec/system/select_spec.rb -e "narrows the list"`
Expected: FAIL — `search` is not a method on the controller, so Stimulus logs a
missing-action error and every item stays visible.

- [ ] **Step 3: Implement `search`**

```js
// Upstream filters on substring rather than prefix — "gent" reaches Argentina —
// and drops non-matching options from the DOM. Here they are hidden: the
// options are server-rendered, so removing one loses it for good.
search() {
  const query = this.searchTarget.value.trim().toLowerCase()

  this.itemTargets.forEach((item) => {
    item.hidden = query !== "" && !item.textContent.trim().toLowerCase().includes(query)
  })

  const matches = this.enabledItems
  if (this.hasListTarget) this.listTarget.hidden = matches.length === 0
  if (this.hasEmptyTarget) this.emptyTarget.hidden = matches.length > 0

  this.highlight(matches[0])
}
```

- [ ] **Step 4: Teach `enabledItems` about hidden items**

```js
get enabledItems() {
  return this.itemTargets.filter((item) => item.dataset.disabled === undefined && !item.hidden)
}
```

This one line is what keeps ArrowDown, Home, End and `selectedItem` out of
filtered-away rows. Nothing hides items when `searchable` is false, so the plain
path is unchanged — the untouched pre-existing examples are the check on that.

- [ ] **Step 5: Green, then verify by mutation**

Run: `bundle exec rspec spec/system/select_spec.rb`
Expected: PASS throughout.

Change `includes(query)` to `startsWith(query)` and confirm "narrows the list to
substring matches" fails with an empty list. Restore, then drop `&& !item.hidden`
and confirm "keeps the arrow keys inside what is left" fails. Restore both and
check `git diff`.

- [ ] **Step 6: Commit**

```sh
bundle exec rake && bin/rubocop
git add app/javascript/shadcn/controllers/select_controller.js spec/system/select_spec.rb
git commit -m "Filter the searchable select's options as the query changes"
```

---

### Task 6: The keys a text field owns, and the close cycle

**Files:**
- Modify: `app/javascript/shadcn/controllers/select_controller.js`
- Test: `spec/system/select_spec.rb`

**Interfaces:**
- Consumes: everything from Tasks 4 and 5.
- Produces: the finished component.

`contentKeydown` is bound on the content and keydowns from the search field
bubble to it, so it already fires — which is a problem as much as a convenience.
Three cases must stand down when the field has focus: **Space** currently selects
and in a text field is a space; **Home/End** currently jump the highlight and in a
text field move the caret; **single characters** currently drive the typeahead,
which would accumulate a second, invisible query. ArrowUp, ArrowDown, Enter,
Escape and Tab keep their meaning.

- [ ] **Step 1: Write the failing specs**

```ruby
it "lets the search field keep the keys that belong to a text field" do
  fill_in_search("g")
  press(:space)
  press(:home)

  within(preview) do
    expect(find("[data-slot=select-input]").value).to eq("g ")
    expect(page).to have_css(content)
  end
end

it "chooses the highlighted option with Enter" do
  fill_in_search("pine")
  press(:enter)

  within(preview) { expect(page).to have_no_css(content) }
  expect(value).to eq("pineapple")
end

it "starts from a clean query the next time it opens" do
  fill_in_search("pine")
  press(:escape)
  expect(page).to have_no_css(content)

  within(preview) { find(trigger).click }
  expect(page).to have_css(content)

  within(preview) { expect(find("[data-slot=select-input]").value).to eq("") }
  expect(visible_item_values).to eq(%w[apple banana blueberry grapes pineapple])
end
```

The first asserts the panel is *still open* after Space, which is the regression
that matters: Space used to select, and selecting closes.

- [ ] **Step 2: Run them and watch them fail**

Run: `bundle exec rspec spec/system/select_spec.rb -e "belong to a text field"`
Expected: FAIL — the panel has closed, because Space selected the highlighted
option.

- [ ] **Step 3: Stand the three cases down**

Guard the cases, not the whole handler:

```js
case "Home":
  if (this.searchableValue) return
  event.preventDefault()
  this.highlight(items[0])
  return
case "End":
  if (this.searchableValue) return
  event.preventDefault()
  this.highlight(items[items.length - 1])
  return
case "Enter":
case " ":
  // A space is a character while the search field has focus; Enter still
  // chooses. Without this, typing a space closes the panel.
  if (event.key === " " && this.searchableValue) return
  if (!this.highlighted) return
  event.preventDefault()
  this.highlighted.click()
  return
```

and the typeahead branch at the end:

```js
if (!this.searchableValue && event.key.length === 1 && !event.metaKey && !event.ctrlKey) {
  const match = this.typeahead.search(event.key, this.enabledItems, this.highlighted)
  if (match) this.highlight(match)
}
```

- [ ] **Step 4: Reset the query on close**

In `onClose`, after `this.clearHighlight()`:

```js
if (this.searchableValue && this.hasSearchTarget) {
  this.searchTarget.value = ""
  this.search()
}
```

Calling `search()` rather than unhiding by hand keeps one definition of what the
list looks like for a given query, empty state and list `hidden` included.

- [ ] **Step 5: Green, then verify by mutation**

Run: `bundle exec rspec spec/system/select_spec.rb`
Expected: PASS.

Remove the `event.key === " " && this.searchableValue` guard and confirm the
first example fails with the panel closed. Restore, remove the `onClose` reset,
and confirm the third fails with `"pine"` still in the field. Restore.

- [ ] **Step 6: Confirm the wiring and the plain path**

Run: `bundle exec rspec spec/system/select_spec.rb spec/system/accessibility_spec.rb spec/stimulus_contract_spec.rb`
Expected: PASS. `stimulus_contract_spec` picks up the new value, targets and
action automatically; a failure there means a `data-` name in Task 3's markup and
one in the controller disagree.

- [ ] **Step 7: Commit**

```sh
bundle exec rake && bin/rubocop
git add app/javascript/shadcn/controllers/select_controller.js spec/system/select_spec.rb
git commit -m "Give the search field the keys a text field owns"
```

---

### Task 7: Documentation, and the FormBuilder claim

**Files:**
- Modify: `README.md`, `.claude/docs/todo.md`
- Test: `spec/form_builder_spec.rb`

- [ ] **Step 1: Verify the FormBuilder needs no change, by testing it**

`shadcn_select` forwards `**options` to `Shadcn::Select::Component.new`
(`lib/shadcn_view_component/form_builder.rb:78-82`), so `searchable:` should
already reach it. That is a claim, so it gets an example:

```ruby
it "passes searchable through to the select" do
  html = builder.shadcn_select(:fruit, %w[Apple Banana], searchable: true)

  expect(html).to include('data-shadcn--select-searchable-value="true"')
end
```

Run it. If it fails, the FormBuilder does need a change and this is where that is
discovered — do not adjust the expectation to match the output.

- [ ] **Step 2: Document the option in `README.md`**

In the select's section: what `searchable:` does, that the filter is client-side
over the options already rendered, and the sentence that matters for a real app —
for a list long enough to need a round trip, listen for `input` on
`[data-slot=select-input]` and swap the options through a Turbo Frame. Do not
promise a built-in server mode; none was built.

Say plainly that this component is the gem's own rather than a port of a Radix
component, and point at `decisions/01-architecture.md` for why.

- [ ] **Step 3: Update `todo.md`**

Two edits.

The "Components not ported" section treats filtering as blocked behind `combobox`
and `command`. Amend that: a filtering *select* now exists, while `command`'s
palette and `combobox`'s free-text entry are still unported and still blocked on
npm. Do not delete the entry.

Then add an entry recording what the investigation turned up and this plan did
not act on: **shadcn's registry has moved to bases × styles, and `new-york-v4` is
the legacy one.** Record what was measured — 61 components each, differing by
`questionnaire` and `form`; four files byte-identical to the vendored copies; the
changelog's "Radix is not being deprecated" — and what was not established, which
is whether `new-york-v4` will keep pace. Note that following the new architecture
would mean adopting `cn-*` semantic classes plus the style sheets that define
them, which is a different gem, and that it would not have delivered this
component anyway, since `bases/radix` has no searchable select either.

- [ ] **Step 4: Commit**

```sh
bundle exec rake && bin/rubocop
git add README.md .claude/docs spec/form_builder_spec.rb
git commit -m "Document the searchable select and the registry it is not from"
```

---

## What this plan does not do

- **No free-text entry.** The field filters; it never becomes the value. That is
  `combobox`, still blocked on `@base-ui/react`.
- **No server-side filtering.** The README says how to wire one; the gem takes no
  position.
- **No `aria-live` announcement** when the filter empties the list. Upstream has
  none either and axe does not ask for one — but axe is not a screen reader, and
  this is exactly the sort of gap it cannot see. Worth a todo, not a guess.
- **No move to the new registry architecture.** Task 7 records the question; it
  does not answer it.
