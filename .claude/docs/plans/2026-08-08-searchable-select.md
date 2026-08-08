# Searchable Select Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `searchable:` to `Shadcn::Select::Component`, so an open select shows
a filter field above its options, reproducing the markup shadcn's React Aria
variant emits.

**Architecture:** When `searchable:` is true the popover becomes
`role="dialog"` containing a search field and a *separate* `role="listbox"`,
which is what upstream does and the only structure that survives axe — a text
field cannot be a child of a listbox. The highlight stops moving DOM focus and
becomes virtual (`aria-activedescendant`), because focus has to stay in the
field for typing to work. Filtering hides non-matching items rather than
removing them, since the items are server-rendered ERB. When `searchable:` is
false nothing about the component changes.

**Tech Stack:** ViewComponent, `view_component-contrib` StyleVariants, Stimulus,
Capybara + headless Chrome, axe-rspec.

## Background — read this before Task 1

The shape was not designed here. It was measured off `ui.shadcn.com`, and four
candidate shapes were audited on branch `feature/select-searchable` (commits
`3e5722f`, `c224353`). What that established:

- **The popover is `role="dialog"`, not a listbox.** Putting the search input
  inside our current `SelectContent` — which carries `role="listbox"` — is a
  *critical* axe violation, `aria-required-children`: "Element has children
  which are not allowed: input[aria-controls]".
- **Upstream's trigger is a plain `<button>`** with `aria-haspopup="listbox"`
  and no `role`. All eight aria-variant triggers on that page are role-less.
- **Upstream's search input has no accessible name** — no `aria-label`, no
  `aria-labelledby`, no `placeholder` — and axe calls that a *critical* `label`
  violation. Naming it is the one deviation this port owes upstream.
- Upstream composes `input-group`, which this gem already ships.

The spike previews and `spec/system/select_searchable_spike_spec.rb` are
scaffolding. Task 3 deletes them.

## Global Constraints

- **`searchable:` defaults to `false`, and a non-searchable select must be
  byte-identical to today** apart from the new `data-shadcn--select-searchable-value`
  attribute. Regenerate snapshots once, in Task 3, and check the diff is only
  that attribute plus the new preview's own file.
- **Markup follows upstream's aria variant**, with exactly two documented
  deviations: the search input gets an accessible name, and the empty state sits
  outside the listbox rather than inside it with `role="option"`.
- **No npm dependency.** The magnifier is inlined like every other icon.
- **Never split a class string across a `\` line continuation** — Tailwind scans
  source text, so half a token generates no CSS. Concatenate whole tokens.
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
| `vendor/shadcn/aria/select.tsx` | the reference this port is answerable to; a citation source, policed by no spec |
| `vendor/shadcn/aria/REVISION` | the upstream commit it was taken at |
| `vendor/shadcn/aria/README.md` | says what it is and that nothing checks it |
| `app/components/shadcn/select/list/component.rb` | `data-slot="select-list"`, `role="listbox"` — the element the options actually live in |
| `app/components/shadcn/select/search/component.rb` | the filter field: wrapper, `InputGroup`, `<input data-slot="select-input">`, magnifier addon |
| `app/components/shadcn/select/empty/component.rb` | `data-slot="select-empty"`, shown when the filter matches nothing |
| `app/components/shadcn/select/previews/searchable.html.erb` | the preview that makes this covered by snapshot, preview and accessibility specs |

**Modified**

| File | Change |
|---|---|
| `app/components/shadcn/select/component.rb` | `searchable:` keyword, its data value, lambda slots passing it to trigger and content |
| `app/components/shadcn/select/content/component.rb` | `role="dialog"` when searchable; renders search + list + empty around the items |
| `app/components/shadcn/select/trigger/component.rb` | drops `role="combobox"` for `aria-haspopup="listbox"` when searchable |
| `app/components/shadcn/icon/component.rb` | adds the `search` path |
| `app/javascript/shadcn/controllers/select_controller.js` | virtual focus, filtering, key handling, close behaviour |
| `app/components/shadcn/select/preview.rb` | registers `searchable`, drops the five spike previews |
| `spec/system/select_spec.rb` | a `when searchable` context |
| `.claude/docs/todo.md`, `.claude/docs/decisions/01-architecture.md`, `README.md` | see Task 7 |

**Deleted** (Task 3): the five `spike_*.html.erb` previews, their `preview.rb`
methods, and `spec/system/select_searchable_spike_spec.rb`.

---

### Task 1: Vendor the aria variant as a citation source

**Files:**
- Create: `vendor/shadcn/aria/select.tsx`, `vendor/shadcn/aria/REVISION`, `vendor/shadcn/aria/README.md`
- Modify: `vendor/shadcn/README.md`, `.claude/docs/decisions/03-testing.md`

**Interfaces:**
- Produces: `vendor/shadcn/aria/select.tsx`, the file every later task copies
  class strings and attribute names out of.

It goes in `vendor/shadcn/aria/`, **not** `vendor/shadcn/ui/`. `ShadcnSource#vendored_components`
is a flat glob — `Dir[VENDOR.join("*.tsx")]` at `spec/support/shadcn_source.rb:27-28` —
so a file in `ui/` would join the parity list and collide with the Radix
`select.tsx` already there. A subdirectory is invisible to it.

- [ ] **Step 1: Fetch the source and find the aria select**

```sh
git clone --depth 1 https://github.com/shadcn-ui/ui /tmp/shadcn-ui
grep -rl "react-aria-components" /tmp/shadcn-ui/apps/v4/registry/ | grep -i select
```

The install command on the docs page is `pnpm dlx shadcn@latest add select`, so
the file is named `select.tsx` inside whichever registry directory the grep
reports. If the grep returns nothing, stop and report it rather than guessing a
path — the variant may be published from a registry that is not in this repo,
and in that case the classes have to come from the rendered page instead.

- [ ] **Step 2: Copy it and record the revision**

```sh
mkdir -p vendor/shadcn/aria
cp <the path grep reported> vendor/shadcn/aria/select.tsx
(cd /tmp/shadcn-ui && git rev-parse HEAD) > vendor/shadcn/aria/REVISION
```

- [ ] **Step 3: Write `vendor/shadcn/aria/README.md`**

```markdown
# The React Aria select

`ui.shadcn.com/docs/components/aria/select` — one of the three variants shadcn
now publishes, and the only one with a searchable example. Copied verbatim at
the revision in `REVISION`.

This gem ports the **Radix** variant; `../ui/select.tsx` is that one. This file
is here for a single component, the searchable select, whose shape has no
counterpart in Radix.

**No spec reads this.** `parity_spec` globs `../ui/*.tsx` and never descends
here, so nothing detects it going stale — the same standing as `vendor/radix/`.
Check it against the site before trusting it.
```

- [ ] **Step 4: Add a row to `vendor/shadcn/README.md`'s table**

```markdown
| `aria/` | the React Aria variant, for the searchable select | nothing — see `aria/README.md` |
```

- [ ] **Step 5: Extend the vendored-references section in the decisions doc**

`.claude/docs/decisions/03-testing.md` has a section "What the two vendored
references are worth". There are three now. Add a paragraph naming
`vendor/shadcn/aria/` alongside `vendor/radix/` as policed by nobody, and
change the heading and the `.claude/docs/README.md` row that quotes it from
"two" to "three".

- [ ] **Step 6: Verify parity is unaffected, then commit**

Run: `bundle exec rspec spec/parity_spec.rb`
Expected: PASS, same example count as before the task — proof the new file did
not join `vendored_components`.

```sh
bundle exec rake && bin/rubocop
git add vendor/shadcn .claude/docs
git commit -m "Vendor the aria select as a citation source"
```

---

### Task 2: Bundle the magnifier icon

**Files:**
- Modify: `app/components/shadcn/icon/component.rb`
- Test: `spec/components/shadcn/icon_spec.rb`

**Interfaces:**
- Produces: `Shadcn::Icon::Component.new("search")` renders without raising.

`PATHS` at `icon/component.rb:14` holds eleven icons. `search` is not among
them, and an unknown name **raises** where `Rails.env.local?` — which is why the
first draft of the spike preview failed to render at all rather than showing a
missing icon.

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
Expected: FAIL — an unknown icon name raises, so the error is the raise, not a
missing element.

- [ ] **Step 3: Add the path**

In the `PATHS` hash in `app/components/shadcn/icon/component.rb`, keeping the
hash's existing alphabetical-ish grouping and its `%(...)` literal style:

```ruby
"search" => %(<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>),
```

That is lucide's `search`, the same drawing upstream's addon renders.

- [ ] **Step 4: Green**

Run: `bundle exec rspec spec/components/shadcn/icon_spec.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```sh
bundle exec rake && bin/rubocop
git add app/components/shadcn/icon/component.rb spec/components/shadcn/icon_spec.rb
git commit -m "Bundle lucide's search icon"
```

---

### Task 3: The markup, with no behaviour yet

**Files:**
- Create: `app/components/shadcn/select/list/component.rb`, `app/components/shadcn/select/search/component.rb`, `app/components/shadcn/select/empty/component.rb`, `app/components/shadcn/select/previews/searchable.html.erb`
- Modify: `app/components/shadcn/select/component.rb`, `app/components/shadcn/select/content/component.rb`, `app/components/shadcn/select/trigger/component.rb`, `app/components/shadcn/select/preview.rb`
- Delete: `app/components/shadcn/select/previews/spike_*.html.erb`, `spec/system/select_searchable_spike_spec.rb`
- Test: `spec/system/accessibility_spec.rb` (no edit — it discovers the preview), `spec/snapshot_spec.rb` (regenerate)

**Interfaces:**
- Consumes: `Shadcn::Icon::Component.new("search")` from Task 2; the class
  strings in `vendor/shadcn/aria/select.tsx` from Task 1.
- Produces: `Shadcn::Select::Component.new(searchable: true)`, emitting
  `data-shadcn--select-searchable-value`; `Select::List::Component`,
  `Select::Search::Component`, `Select::Empty::Component`; targets named
  `search`, `list` and `empty` for Task 4 to drive.

**Every class string in this task comes from `vendor/shadcn/aria/select.tsx`,
copied verbatim.** Do not retype them from this plan or from the rendered page —
the plan does not contain them precisely because hand-copied Tailwind is how
tokens get corrupted.

None of these three are declared with the `part` macro. `part` "declares a slot,
classes and a tag, and no other attribute"
(`.claude/docs/decisions/01-architecture.md`), and all three carry more: `List`
has `role="listbox"`, `Search` has a whole subtree, `Empty` renders `hidden`.
`ItemGroup` is the precedent for a part that grew its own `component.rb` for
exactly one attribute.

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
Expected: FAIL — the preview does not exist yet, so `visit_preview` raises
before any assertion runs.

- [ ] **Step 3: Create `Select::List::Component`**

```ruby
# frozen_string_literal: true

module Shadcn
  module Select
    module List
      # The element the options live in. In the non-searchable select the
      # listbox role sits on SelectContent itself; a searchable one cannot do
      # that, because a text field is not an allowed child of a listbox — axe
      # reports `aria-required-children`, critical. Upstream splits them the
      # same way.
      class Component < ApplicationViewComponent
        slot_name :"select-list"

        style do
          base { "<copy from vendor/shadcn/aria/select.tsx>" }
        end

        def element_attributes(**defaults)
          super(**{ role: "listbox", "data-shadcn--select-target" => "list" }.merge(defaults))
        end
      end
    end
  end
end
```

- [ ] **Step 4: Create `Select::Search::Component`**

The subtree is `select-input-wrapper` > `input-group` > [`select-input`,
`input-group-addon`], which is what the rendered upstream popover contains.

```ruby
# frozen_string_literal: true

module Shadcn
  module Select
    module Search
      # The filter field. Composes the already-ported InputGroup, as upstream
      # does — its popover renders `data-slot="input-group"` around the field.
      #
      # `aria-label` is this port's one deliberate addition: upstream's input
      # carries no accessible name at all, which axe reports as a critical
      # `label` violation.
      class Component < ApplicationViewComponent
        slot_name :"select-input-wrapper"

        style do
          base { "<copy from vendor/shadcn/aria/select.tsx>" }
        end

        attr_reader :label

        def initialize(label: nil, **attributes)
          @label = label
          super(**attributes)
        end

        def call
          render_element(body: render(InputGroup::Component.new) do
            safe_join([ field, addon ])
          end)
        end

        private

        def field
          tag.input(
            type: "text",
            "data-slot": "select-input",
            "aria-label": label || t("shadcn.select.search_label"),
            "aria-autocomplete": "list",
            "data-shadcn--select-target": "search",
            "data-action": "input->shadcn--select#search",
            class: "<copy from vendor/shadcn/aria/select.tsx>"
          )
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

Add the default string to `config/locales/en.yml` under the existing `shadcn:`
tree, following whatever key style the file already uses:

```yaml
select:
  search_label: "Search options"
  empty: "No results found."
```

- [ ] **Step 5: Create `Select::Empty::Component`**

```ruby
# frozen_string_literal: true

module Shadcn
  module Select
    module Empty
      # Shown when the filter matches nothing.
      #
      # Deliberately a *sibling* of the listbox rather than a child of it.
      # Upstream nests its empty state inside the list and gives it
      # `role="option"`, which is how React Aria's collection renders it — an
      # option that cannot be chosen. Outside the list the question does not
      # arise, and the shape that put a non-option inside a listbox is the one
      # axe rejected.
      class Component < ApplicationViewComponent
        slot_name :"select-empty"

        style do
          base { "<copy from vendor/shadcn/aria/select.tsx>" }
        end

        def element_attributes(**defaults)
          super(**{
            hidden: true,
            "data-shadcn--select-target" => "empty"
          }.merge(defaults))
        end

        def call
          render_element(body: content.presence || t("shadcn.select.empty"))
        end
      end
    end
  end
end
```

- [ ] **Step 6: Thread `searchable` through the root**

In `app/components/shadcn/select/component.rb`, replace the two `renders_one`
lines and extend the constructor. Lambda slots are how `ToggleGroup` already
passes group-level state to its children (`toggle_group/component.rb:10`).

```ruby
renders_one :trigger, ->(**kwargs, &block) {
  Trigger::Component.new(searchable:, **kwargs, &block)
}
renders_one :select_content, ->(**kwargs, &block) {
  Content::Component.new(searchable:, **kwargs, &block)
}
```

```ruby
attr_reader :open, :value, :name, :placeholder, :side, :align, :side_offset, :searchable

def initialize(value: nil, name: nil, placeholder: nil, open: false,
               side: :bottom, align: :center, side_offset: 4, searchable: false,
               **attributes)
  @searchable = searchable
  # …existing assignments unchanged…
end
```

and in `element_attributes`, alongside the other values:

```ruby
"data-shadcn--select-searchable-value" => searchable
```

- [ ] **Step 7: Make the trigger a plain button when searchable**

In `trigger/component.rb`, add `searchable: false` to the constructor and
`attr_reader`, then branch the two attributes:

```ruby
def element_attributes(**defaults)
  super(**{
    type: "button",
    role: ("combobox" unless searchable),
    "aria-haspopup" => ("listbox" if searchable),
    "aria-autocomplete" => ("none" unless searchable),
    disabled: (true if disabled),
    # …the rest unchanged…
  }.merge(defaults))
end
```

`role: nil` omits the attribute rather than emitting an empty one, which is what
the spike relied on.

- [ ] **Step 8: Restructure the content when searchable**

In `content/component.rb`, add `searchable: false` to the constructor and
`attr_reader`. Then `role` becomes conditional and the body gains the three new
parts:

```ruby
def element_attributes(**defaults)
  super(**{
    role: (searchable ? "dialog" : "listbox"),
    "aria-label" => (t("shadcn.select.dialog_label") if searchable),
    tabindex: "-1",
    # …the rest unchanged…
  }.merge(defaults))
end

def call
  render_element(body: safe_join([
    scroll_button("select-scroll-up-button", "chevron-up"),
    viewport,
    scroll_button("select-scroll-down-button", "chevron-down")
  ].compact))
end
```

`viewport` becomes:

```ruby
def viewport
  inner = if searchable
            safe_join([
              render(Search::Component.new),
              render(List::Component.new) { safe_join([ items, content ].flatten.compact) },
              render(Empty::Component.new)
            ])
          else
            safe_join([ items, content ].flatten.compact)
          end

  tag.div(inner, class: viewport_classes)
end
```

Add `dialog_label: "Options"` to the locale file beside the other two keys.

Note the scroll buttons stay. Upstream's searchable popover has none, because
its filter replaces scrolling — if the vendored source confirms that, drop them
when `searchable` and say so in the commit; if it does not, leave them.

- [ ] **Step 9: Write the preview**

`app/components/shadcn/select/previews/searchable.html.erb`, modelled on
`default.html.erb` — same fruits, so the existing specs' vocabulary carries
over, plus enough entries that filtering is visible:

```erb
<%= render(Shadcn::Select::Component.new(name: "fruit", placeholder: "Select a fruit", searchable: true)) do |s| %>
  <%# `role="combobox"` is gone here, so the trigger takes its name from its own
      content — but the FormBuilder's habit of pointing a name at it still holds. %>
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

Register it in `select/preview.rb` and **delete the five spike methods** in the
same edit:

```ruby
def searchable
  render_with_template
end
```

- [ ] **Step 10: Delete the spike**

```sh
rm app/components/shadcn/select/previews/spike_*.html.erb
rm spec/system/select_searchable_spike_spec.rb
```

- [ ] **Step 11: Green, then regenerate snapshots and read the diff**

Run: `bundle exec rspec spec/system/select_spec.rb -e "when searchable"`
Expected: PASS.

```sh
SNAPSHOTS=overwrite bundle exec rspec spec/snapshot_spec.rb
git diff --stat spec/fixtures/snapshots/
```

Expected: `select-searchable.html` added, and every other changed snapshot
differing **only** by `data-shadcn--select-searchable-value="false"`. Two
existing files change — the select's own and `theme_selector`'s, which is also a
Select. If anything else moved, stop: the default path was not meant to change.

- [ ] **Step 12: Confirm axe is clean on the real component**

`accessibility_spec.rb` audits `default.html.erb` per family, so it does not see
this preview. Add one example to it, beside the existing `with the select open`
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
Expected: PASS. A `label` violation here means the search field lost its
`aria-label`; `aria-required-children` means the items ended up outside
`select-list`.

- [ ] **Step 13: Commit**

```sh
bundle exec rake && bin/rubocop
git add -A app/components/shadcn/select app/components/shadcn/icon config/locales spec
git commit -m "Render the searchable select's markup"
```

---

### Task 4: Virtual focus

**Files:**
- Modify: `app/javascript/shadcn/controllers/select_controller.js`
- Test: `spec/system/select_spec.rb`

**Interfaces:**
- Consumes: targets `search`, `list`, `empty` from Task 3.
- Produces: `highlight()` honouring `searchableValue`; every item carrying a
  generated `id`.

The existing `highlight()` calls `item.focus()`. In a searchable select that
would pull focus out of the field on the first arrow key and typing would stop
working. Upstream keeps DOM focus on the input and points
`aria-activedescendant` at the active option, which also carries `data-focused`.

- [ ] **Step 1: Write the failing spec**

In the `when searchable` context added in Task 3:

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

`highlighted` is the method already defined at the top of `select_spec.rb`; it
reads `[data-slot=select-item][data-highlighted]`, which stays correct here
because the highlight attribute does not change — only what focus does.

The expectation is `banana` and not `apple` because `onOpen` already highlights
the first item, so the first ArrowDown is a move from it.

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

`input` is already taken by the hidden form field, which is why the text field's
target is `search`.

- [ ] **Step 4: Give the items ids and wire the input at connect**

In `connect()`, after the existing `this.contentTarget.id ||= …` line:

```js
if (this.searchableValue && this.hasSearchTarget && this.hasListTarget) {
  this.listTarget.id ||= uniqueId("shadcn-select-list")
  this.searchTarget.setAttribute("aria-controls", this.listTarget.id)
  this.itemTargets.forEach((item) => (item.id ||= uniqueId("shadcn-select-item")))
}
```

The ids are generated here for the same reason the content's is: the server
cannot know them, and `crypto.randomUUID()` is secure-context only — which is
what `uniqueId` exists to avoid.

- [ ] **Step 5: Branch `highlight` and `clearHighlight`**

```js
highlight(item) {
  this.clearHighlight()
  if (!item) return

  item.dataset.highlighted = ""

  if (this.searchableValue) {
    // Focus stays in the field, or typing stops. Upstream marks the active
    // option the same way, with aria-activedescendant plus data-focused.
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

In the `onOpen` callback:

```js
onOpen: () => {
  this.triggerTarget.setAttribute("aria-expanded", "true")
  this.typeahead.reset()
  if (this.searchableValue && this.hasSearchTarget) {
    this.searchTarget.focus({ preventScroll: true })
  } else {
    this.contentTarget.focus({ preventScroll: true })
  }
  this.highlight(this.selectedItem || this.enabledItems[0])
}
```

- [ ] **Step 7: Green, then verify by mutation**

Run: `bundle exec rspec spec/system/select_spec.rb`
Expected: PASS, including every pre-existing example — the non-searchable path
must be untouched.

Now break it: change the `searchableValue` test in `highlight` to `false &&
this.searchableValue`, re-run the new example, and confirm it fails on the
`activeElement` assertion. Restore, and confirm `git diff` on the controller is
back to the intended change. A spec that cannot be broken this way is not
testing the branch.

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
- Consumes: the `search`, `list` and `empty` targets and `searchableValue` from
  Task 4.
- Produces: a `search()` action, already referenced by
  `data-action="input->shadcn--select#search"` in Task 3; `enabledItems`
  excluding filtered-out items.

Upstream filters case-insensitively on **substring**, not prefix — typing `gent`
reaches Argentina — and removes non-matching options from the DOM. This port
hides them instead: the options are server-rendered ERB, and an option removed
from the DOM cannot be put back.

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

with two helpers beside the existing `highlighted`, both methods rather than
`let` because each is read after a keystroke has changed the DOM:

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
// and drops non-matching options from the DOM. Here they are hidden instead:
// the options are server-rendered, so removing one loses it for good.
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

This one line is what keeps ArrowDown, Home, End and `selectedItem` from walking
into filtered-out rows. Nothing hides items when `searchable` is false, so the
existing behaviour is unchanged — which the untouched pre-existing examples are
the check on.

- [ ] **Step 5: Green, then verify by mutation**

Run: `bundle exec rspec spec/system/select_spec.rb`
Expected: PASS throughout.

Break `includes(query)` to `startsWith(query)` and confirm "narrows the list to
substring matches" fails, reporting an empty list. Then break `enabledItems`
back to ignoring `hidden` and confirm "keeps the arrow keys inside what is left"
fails. Restore both and check `git diff`.

- [ ] **Step 6: Commit**

```sh
bundle exec rake && bin/rubocop
git add app/javascript/shadcn/controllers/select_controller.js spec/system/select_spec.rb
git commit -m "Filter the searchable select's options as the query changes"
```

---

### Task 6: Keys and the close cycle

**Files:**
- Modify: `app/javascript/shadcn/controllers/select_controller.js`
- Test: `spec/system/select_spec.rb`

**Interfaces:**
- Consumes: everything from Tasks 4 and 5.
- Produces: the finished component.

`contentKeydown` is bound on the content, and keydowns from the search field
bubble to it, so it already fires — which is a problem as much as a convenience.
Three of its cases must stand down when the field has focus:

- **Space** currently selects the highlighted item. In a text field a space is a
  space.
- **Home / End** currently jump the highlight. In a text field they move the
  caret.
- **Single characters** currently drive the typeahead. The field owns them now,
  and `Typeahead` would accumulate a second, invisible query.

ArrowUp, ArrowDown, Enter, Escape and Tab keep their meaning.

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

The first example asserts the panel is still open after Space, which is the
regression that matters: Space used to select, and selecting closes.

- [ ] **Step 2: Run them and watch them fail**

Run: `bundle exec rspec spec/system/select_spec.rb -e "belong to a text field"`
Expected: FAIL — the panel has closed, because Space selected the highlighted
option.

- [ ] **Step 3: Stand the three cases down**

In `contentKeydown`, guard the cases rather than the whole handler:

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

In the `onClose` callback, after `this.clearHighlight()`:

```js
if (this.searchableValue && this.hasSearchTarget) {
  this.searchTarget.value = ""
  this.search()
}
```

Calling `search()` rather than unhiding by hand keeps one definition of "what
the list looks like for this query", including the empty state and the list's
own `hidden`.

- [ ] **Step 5: Green, then verify by mutation**

Run: `bundle exec rspec spec/system/select_spec.rb`
Expected: PASS.

Remove the `event.key === " " && this.searchableValue` guard and confirm the
first example fails with the panel closed. Remove the `onClose` reset and
confirm the third fails with `"pine"` still in the field. Restore both.

- [ ] **Step 6: Confirm the non-searchable select is untouched**

Run: `bundle exec rspec spec/system/select_spec.rb spec/system/accessibility_spec.rb spec/stimulus_contract_spec.rb`
Expected: PASS. `stimulus_contract_spec` gains examples for the new value and
targets automatically; if it reports a missing target or action, a `data-` name
in Task 3's markup and one in the controller disagree.

- [ ] **Step 7: Commit**

```sh
bundle exec rake && bin/rubocop
git add app/javascript/shadcn/controllers/select_controller.js spec/system/select_spec.rb
git commit -m "Give the search field the keys a text field owns"
```

---

### Task 7: Documentation, and the FormBuilder claim

**Files:**
- Modify: `README.md`, `.claude/docs/todo.md`, `.claude/docs/decisions/01-architecture.md`
- Test: `spec/form_builder_spec.rb`

**Interfaces:**
- Consumes: the finished component.

- [ ] **Step 1: Verify the FormBuilder needs no change, by testing it**

`shadcn_select` forwards `**options` to `Shadcn::Select::Component.new`
(`lib/shadcn_view_component/form_builder.rb:78-82`), so `searchable:` should
already reach it. That is a claim, so it gets an example rather than a sentence.
In `spec/form_builder_spec.rb`:

```ruby
it "passes searchable through to the select" do
  html = builder.shadcn_select(:fruit, %w[Apple Banana], searchable: true)

  expect(html).to include('data-shadcn--select-searchable-value="true"')
end
```

Run it. If it fails, the FormBuilder does need a change and this step is where
that is discovered — do not adjust the expectation to match the output.

- [ ] **Step 2: Document the option in `README.md`**

In the section covering the select, one short subsection: what `searchable:`
does, that the filter is client-side over the options already rendered, and the
sentence that matters for a real app — for a list long enough to need a server
round trip, listen for `input` on `[data-slot=select-input]` and swap the
options through a Turbo Frame. Do not promise a built-in server mode; none was
built.

- [ ] **Step 3: Record the deviations in `01-architecture.md`**

Beside the `loop:` entry added in the same spirit, a short entry naming the two
places this port does not match upstream and why: the search input gets an
accessible name because upstream's has none and axe calls that critical, and the
empty state sits outside the listbox because a non-option inside one is what axe
rejected in the discarded shape. Cite the measured violations rather than
describing them as likely.

- [ ] **Step 4: Update `todo.md`**

The "Components not ported" section says searchable selection is blocked behind
`combobox` and `command`, both stuck on npm. That is now only half true: a
filtering select exists without either. Amend that paragraph — do not delete the
entry, since `command`'s palette and `combobox`'s free-text entry are still
unported and still blocked.

- [ ] **Step 5: Commit**

```sh
bundle exec rake && bin/rubocop
git add README.md .claude/docs spec/form_builder_spec.rb
git commit -m "Document the searchable select and what it deviates on"
```

---

## What this plan does not do

- **No free-text entry.** The field filters; it never becomes the value. That is
  `combobox`, still blocked on `@base-ui/react`.
- **No server-side filtering.** The README says how to wire one; the gem takes no
  position.
- **No `aria-live` announcement** when the filter empties the list. Upstream has
  none either, and axe does not ask for one — but axe is not a screen reader,
  and this is exactly the kind of gap it cannot see. Worth a todo, not a guess.
- **No scroll-button decision made blind.** Task 3 Step 8 leaves them in place
  unless the vendored source shows upstream drops them.
