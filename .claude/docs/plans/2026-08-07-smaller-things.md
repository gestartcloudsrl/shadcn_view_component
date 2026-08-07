# Closing the smaller things

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close 11 of the 12 open entries under *Smaller things* in
[todo.md](../todo.md), and delete them from the list as they land.

**Architecture:** Ten independent tasks. Nothing here depends on anything else
here, so a task that turns out badly can be dropped without stranding its
neighbours. They are ordered so the spec-suite changes land first — every later
task is verified by that suite, and it is better to be running the version we
mean to keep.

**Tech Stack:** Rails engine, ViewComponent + StyleVariants, Stimulus, Tailwind
4, RSpec + Capybara.

**Read first:** the `viewcomponent-guideline` and `rspec-conventions` skills in
`.claude/skills/`.

---

## The design

### The three decisions, already taken

**`Icon` gets a registry, and stops being able to take down a host's page.**
`Shadcn::Icon.register(name, path)` covers the ~1,500 lucide icons that are not
bundled. An unknown name raises in `development` and `test` and renders nothing
in `production` — which is what Rails does with missing translations, and the
right shape for a library: a decorative element must not 500 an application we
cannot see.

**`ItemGroup` gets a slot.** `renders_many :items` stamping `role="listitem"`.
The repo's constraint is that upstream wins on *markup* and Rails wins on *API*;
a slot is API, and this is where the FormBuilder precedent puts an accessibility
fix that the component cannot make for itself. The explicit form stays available
for anyone who wants the bare markup.

**The Tailwind build moves to `before(:suite)`.** It costs about 1.5s on every
`rspec` invocation, including one that runs a single component spec. That is the
price of having no tag to remember, it was chosen knowingly, and the comment has
to say so or someone will "optimise" it back.

### The two judgement calls

**`aria-labelledby` everywhere, and the hardcoded id goes.** The argument for
`<label for>` is that it gives click-to-focus for free — but `ThemeSelector`'s
label is `sr-only`, so nobody can click it and the argument evaporates. The
FormBuilder is the general mechanism; ThemeSelector is one component, and it
should follow.

The larger defect is underneath: **`ThemeSelector` hardcodes
`id="theme-selector"`**. Two of them on one page produce duplicate ids, invalid
HTML, and a label that names only the first — and `CLAUDE.md` already documents
that the gallery layout carries one, so a preview is all it takes.

**The two menu controllers get annotated, not merged.** `select_controller` and
`dropdown_menu_controller` share around 60 near-identical lines, and the
differences are deliberate: dropdown wraps around, select clamps. Extracting the
whole thing needs a parameter per divergence, which is how shared code turns into
configuration — the same argument `parts.rb` already makes about not widening
the `part` macro. Extract only what is byte-identical, and leave the rest
separate with a comment naming the divergence where it lives.

### Out of scope, deliberately

`--animate-caret-blink` is the only `infinite` animation in the stylesheet and
so the strongest reduced-motion candidate in the abstract. The only component
that consumes it is InputOTP, which is not ported. Fixing it now is writing code
for something that does not exist; the todo entry stays.

---

## Global Constraints

- **1:1 with upstream on markup.** Anything that adds an attribute shadcn does
  not emit belongs in the API layer — a slot, the FormBuilder — not in the
  component's own `element_attributes`.
- **`railties >= 7.1`**, so `Rails.env.local?` is available and means
  "development or test".
- **Generated ids follow `shadcn-<thing>-#{SecureRandom.hex(4)}`**, memoised per
  instance. See `checkbox/component.rb:51`.
- **A new generated id must be added to `snapshot_spec`'s normaliser** or every
  snapshot becomes nondeterministic and the suite fails on the next run. The
  regex is at `spec/snapshot_spec.rb:24` and currently knows only
  `shadcn-(checkbox|switch)-`.
- **Never split a Tailwind class string across a `\` line continuation.**
- **Attribute precedence is `data-slot` < component defaults < caller.**
- **Every task ends with** `bundle exec rake`, then `bin/rubocop`, then its own
  todo entry deleted in the same commit.

---

## File Structure

| file | task | responsibility |
|---|---|---|
| `spec/previews_spec.rb` | 1 | **deleted** — subsumed |
| `spec/system/exit_animation_spec.rb` | 1 | two redundant assertions removed |
| `spec/spec_helper.rb` | 2 | the suite-wide Tailwind build |
| `spec/reduced_motion_spec.rb` | 2 | loses its own build hook |
| `app/components/shadcn/icon/component.rb` | 3 | registry + environment-dependent raise |
| `app/components/shadcn/item/group/component.rb` | 4 | the `items` slot |
| `app/components/shadcn/theme_selector/component.rb` | 5 | generated id, `aria-labelledby` |
| `app/javascript/shadcn/controllers/*.js` | 6, 7 | redundant ARIA out; typeahead shared |
| `app/javascript/shadcn/floating.js` | 8 | keeps positioning while fading |
| `app/javascript/shadcn/animation.js` | 9 | `inert` while fading |
| `.claude/docs/decisions/*.md` | 10 | the constraint the `!important` rules add up to |

---

### Task 1: Delete what two specs say twice

**Files:**
- Delete: `spec/previews_spec.rb`
- Modify: `spec/system/exit_animation_spec.rb`
- Modify: `.claude/docs/todo.md`

`previews_spec` renders every preview with
`ApplicationController.renderer.render(inline: File.read(template))` over
`Dir[components.join("*/previews/*.html.erb")]` and asserts the result is
present. `snapshot_spec` uses **the same call over the same glob** and then
diffs the output against a golden. The weaker assertion cannot fail where the
stronger one passes.

Its second example — "has a preview for every component family", `>= 30` — is
also covered, and better: `snapshot_spec`'s "has a preview to snapshot for
nearly every family" derives families from `*/component.rb` and names the one
that is missing, rather than counting.

- [ ] **Step 1: Prove the subsumption before deleting**

Break one preview deliberately and confirm `snapshot_spec` catches it alone:

```bash
echo '<%= render(Shadcn::Nonexistent::Component.new) %>' >> app/components/shadcn/empty/previews/default.html.erb
bundle exec rspec spec/snapshot_spec.rb 2>&1 | tail -5
git checkout app/components/shadcn/empty/previews/default.html.erb
```

Expected: FAIL. Put the output in your report. If it passes, **stop** — the
subsumption argument is wrong and `previews_spec` earns its place.

- [ ] **Step 2: Delete it**

```bash
git rm spec/previews_spec.rb
```

- [ ] **Step 3: Remove the two redundant assertions in `exit_animation_spec`**

Two things repeat there:

- the AlertDialog example asserting `elementFromPoint` is the content, which the
  click example directly beneath it already proves — a click that reaches the
  content proves the content is on top, and proves it the way a user meets it.
  Delete the `elementFromPoint` example, keep the click.
- a `have_no_css(overlay)` line that appears in two examples of the dialog
  group. Keep it in the example whose name is about the overlay disappearing;
  delete it from the other.

Read the file and identify both before editing; do not pattern-match on the
line alone.

- [ ] **Step 4: Run the suite**

```bash
bundle exec rake && bin/rubocop
```

Expected: PASS, with the example count down by the number of previews plus
three.

- [ ] **Step 5: Delete both todo entries and commit**

Remove the *`previews_spec` and `snapshot_spec` overlap* and
*`exit_animation_spec.rb` overlaps itself* entries from
`.claude/docs/todo.md`.

```bash
git add -u
git commit -m "Delete the assertions two specs were making twice

previews_spec used the same renderer over the same glob as snapshot_spec
and asserted less about the result. Verified by breaking a preview and
watching snapshot_spec catch it alone."
```

---

### Task 2: One Tailwind build for the suite

**Files:**
- Modify: `spec/spec_helper.rb`
- Modify: `spec/reduced_motion_spec.rb`
- Modify: `.claude/docs/todo.md`

`reduced_motion_spec` builds the bundle in a `before` hook, so it runs before
its own examples and no others. With `config.order = :random`, a seed that puts
it after `exit_animation_spec` lets that spec assert against whatever the last
build left on disk.

- [ ] **Step 1: Add the build to `spec_helper.rb`**

Inside the existing `RSpec.configure` block:

```ruby
  # The system and reduced-motion specs read the compiled Tailwind bundle, and
  # `config.order = :random` means the spec that used to build it could run
  # after the specs that depend on it — asserting against whatever was last
  # left on disk.
  #
  # Deliberately paid on every invocation, including one that runs a single
  # component spec: about 1.5s, in exchange for no tag to remember and no
  # ordering to reason about. Do not move it back into a per-file hook.
  config.before(:suite) do
    dummy = Pathname(__dir__).join("../test/dummy")
    system(dummy.join("bin/rails").to_s, "tailwindcss:build", chdir: dummy.to_s, exception: true)
  end
```

- [ ] **Step 2: Remove the now-duplicated build from `reduced_motion_spec`**

Delete its `before` hook and the `built` flag it guards. Keep everything the
spec asserts. Its header comment explains why it rebuilds rather than trusting
disk — rewrite that paragraph to point at the suite hook instead of claiming to
do it itself.

- [ ] **Step 3: Prove the hazard is gone**

The failure needed a seed that ordered two files a particular way. Instead,
prove the hook runs before anything else:

```bash
rm -f test/dummy/app/assets/builds/tailwind.css
bundle exec rspec spec/reduced_motion_spec.rb 2>&1 | tail -3
```

Expected: PASS. Without the hook this fails, because nothing else would have
built the bundle. Give me the output.

- [ ] **Step 4: Suite, rubocop, todo, commit**

```bash
bundle exec rake && bin/rubocop
```

Remove the *local run can assert against a stale Tailwind bundle* entry.

```bash
git add -u
git commit -m "Build the Tailwind bundle once, before the suite

reduced_motion_spec built it in a per-file hook, so a random seed could
run the specs that read the bundle before the spec that produced it.
The cost — ~1.5s on every invocation — is deliberate and commented."
```

---

### Task 3: `Icon` stops being able to 500 a host

**Files:**
- Modify: `app/components/shadcn/icon/component.rb`
- Create: `spec/components/shadcn/icon_spec.rb`
- Modify: `.claude/docs/todo.md`, `README.md`

Today `initialize` raises `ArgumentError` on any name outside the 11 bundled
`PATHS`, and there is no way to add a twelfth.

**Interfaces:**
- Produces: `Shadcn::Icon.register(name, path)`, a module method on
  `Shadcn::Icon`, taking two Strings and returning the path. Registered icons
  are looked up exactly like bundled ones.

- [ ] **Step 1: Write the failing spec**

```ruby
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Shadcn::Icon::Component, type: :component do
  describe ".register" do
    before { Shadcn::Icon.register("star", %(<path d="M12 2 15 9l7 .5-5 4 1 7-6-3z"/>)) }

    after { Shadcn::Icon.registered.delete("star") }

    it "renders a registered icon like a bundled one" do
      render_inline(described_class.new("star"))

      expect(page).to have_css("svg.lucide.lucide-star path")
    end
  end

  context "with an unknown name" do
    it "raises, so a typo is loud where it can be fixed" do
      expect { described_class.new("nope") }.to raise_error(ArgumentError)
    end

    it "renders nothing when the environment is not local" do
      allow(Rails.env).to receive(:local?).and_return(false)

      expect(render_inline(described_class.new("nope")).to_html).to be_blank
    end
  end
end
```

- [ ] **Step 2: Run it and watch it fail**

Run: `bundle exec rspec spec/components/shadcn/icon_spec.rb`
Expected: FAIL — `Shadcn::Icon.register` does not exist, and the third example
raises rather than rendering blank.

- [ ] **Step 3: Implement**

Add to the `Shadcn::Icon` module, outside the component class:

```ruby
    # Icons a host has added. Kept separate from PATHS so the bundled set stays
    # a frozen literal and a host cannot redefine one by accident.
    def self.registered
      @registered ||= {}
    end

    # The ported components import eleven lucide icons; lucide has about 1,500.
    # A host that needs another registers its path once, at boot.
    def self.register(name, path)
      registered[name.to_s] = path
    end
```

Then in the component, replace the raise in `initialize` and make `#call`
tolerate a missing path:

```ruby
      def initialize(name, **attributes)
        @name = ALIASES.fetch(name.to_s, name.to_s)

        # Loud where it can be fixed, silent where it cannot. An icon is
        # decorative, and a gem should not be able to take down a page in an
        # application it has never seen — the same trade Rails makes with a
        # missing translation.
        raise ArgumentError, "unknown lucide icon: #{name}" if path.nil? && Rails.env.local?

        super(**attributes)
      end

      def path
        @path ||= PATHS[name] || Shadcn::Icon.registered[name]
      end

      def call
        return "".html_safe if path.nil?

        render_element(body: path.html_safe)
      end
```

- [ ] **Step 4: Green, then the whole suite**

```bash
bundle exec rspec spec/components/shadcn/icon_spec.rb   # expect PASS
bundle exec rake && bin/rubocop
```

- [ ] **Step 5: Document the registry in the README**

Add to the README, near where components are described: how to register an
icon, that unknown names raise in development and test and render nothing in
production, and that eleven are bundled because eleven are used.

- [ ] **Step 6: Todo and commit**

Remove the *`Icon::Component` raises on an unknown name* entry.

```bash
git add -A app/components/shadcn/icon spec/components/shadcn/icon_spec.rb README.md .claude/docs/todo.md
git commit -m "Let hosts register icons, and stop raising in production

Eleven of lucide's ~1,500 are bundled. An unknown name now raises in
development and test — where a typo can be fixed — and renders nothing
in production, because a decorative element should not be able to 500 an
application this gem has never seen."
```

---

### Task 4: `ItemGroup` gets a slot that marks its items

**Files:**
- Modify: `app/components/shadcn/item/group/component.rb`
- Modify: `app/components/shadcn/item/previews/default.html.erb`
- Modify: `spec/fixtures/snapshots/item-default.html`
- Modify: `.claude/docs/todo.md`

`role="list"` obliges `listitem` children; `Item` has no role, so a group of
bare items fails axe's `aria-required-children` as soon as one holds a button.
The component cannot fix this in its own markup without deviating from
upstream — so the fix goes in the API, as the FormBuilder's `aria-labelledby`
does for Select.

- [ ] **Step 1: Write the failing spec**

Add to a new `spec/components/shadcn/item_spec.rb`:

```ruby
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Shadcn::Item::Group::Component, type: :component do
  it "marks slotted items as list items, which role=list obliges" do
    render_inline(described_class.new) do |group|
      group.with_item { "One" }
    end

    expect(page).to have_css("[data-slot=item-group][role=list] > [data-slot=item][role=listitem]")
  end

  # The bare form stays available: it is what upstream's markup is, and a caller
  # who is not building a list should not be forced into list semantics.
  it "leaves an explicitly rendered item alone" do
    render_inline(Shadcn::Item::Component.new) { "One" }

    expect(page).to have_no_css("[role=listitem]")
  end
end
```

- [ ] **Step 2: Run it and watch it fail**

Run: `bundle exec rspec spec/components/shadcn/item_spec.rb`
Expected: FAIL — `with_item` is not defined.

- [ ] **Step 3: Add the slot**

```ruby
        # `role="list"` obliges its children to be `role="listitem"`, and `Item`
        # carries no role upstream. Adding one to the component would deviate on
        # markup; adding one here does not — a slot is API, which is the layer
        # the FormBuilder uses for the same kind of gap on Select.
        renders_many :items, ->(**attributes) {
          Shadcn::Item::Component.new(role: "listitem", **attributes)
        }
```

and render them in `#call` before the block content, the way
`Card::Component` does:

```ruby
        def call
          render_element(body: safe_join([ *items, content ].compact))
        end
```

- [ ] **Step 4: Green, then move the preview onto the slot**

```bash
bundle exec rspec spec/components/shadcn/item_spec.rb   # expect PASS
```

Rewrite `item/previews/default.html.erb` to use `group.with_item`, which removes
the hand-written `role: "listitem"` it currently passes — the preview should
demonstrate the good path, not work around its absence.

- [ ] **Step 5: Regenerate and read the snapshot**

```bash
SNAPSHOTS=overwrite bundle exec rspec spec/snapshot_spec.rb
```

Read `spec/fixtures/snapshots/item-default.html` and confirm every `data-slot="item"`
carries `role="listitem"`, and that the separator between them did not acquire
one. Say in your report what you compared.

- [ ] **Step 6: Suite, rubocop, todo, commit**

```bash
bundle exec rake && bin/rubocop
```

Remove the *`ItemGroup` is `role="list"` and `Item` has no role* entry.

```bash
git add -A app/components/shadcn/item spec .claude/docs/todo.md
git commit -m "Give ItemGroup a slot that marks its items

role=list obliges listitem children and Item has none upstream. Adding
the role to the component would deviate on markup; adding it in a slot
does not — the same layer the FormBuilder uses for Select's accessible
name. The bare form still renders upstream's markup."
```

---

### Task 5: `ThemeSelector` stops hardcoding a DOM id

**Files:**
- Modify: `app/components/shadcn/theme_selector/component.rb`
- Modify: `spec/snapshot_spec.rb`
- Modify: `spec/fixtures/snapshots/theme_selector-*.html`
- Modify: `.claude/docs/todo.md`

Two defects in one place. `id: "theme-selector"` is hardcoded, so two selectors
on a page produce duplicate ids and a label that names only the first — and
`CLAUDE.md` records that the gallery layout carries one, so a preview is enough
to collide. And it names its trigger with `<label for>` while the FormBuilder
uses `aria-labelledby`.

- [ ] **Step 1: Write the failing spec**

Add `spec/components/shadcn/theme_selector_spec.rb`:

```ruby
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Shadcn::ThemeSelector::Component, type: :component do
  it "does not reuse an id between two instances on a page" do
    first = render_inline(described_class.new).to_html
    second = render_inline(described_class.new).to_html

    ids = [ first, second ].map { |html| html[/id="(shadcn-theme-selector-[0-9a-f]{8})"/, 1] }

    expect(ids).to all(be_present)
    expect(ids.uniq.size).to eq(2)
  end

  it "names the trigger with aria-labelledby, as the FormBuilder does" do
    render_inline(described_class.new)

    label = page.find("[data-slot=label]")
    expect(page).to have_css("[data-slot=select-trigger][aria-labelledby='#{label[:id]}']")
  end
end
```

- [ ] **Step 2: Run it and watch it fail**

Run: `bundle exec rspec spec/components/shadcn/theme_selector_spec.rb`
Expected: FAIL — the id is the literal `theme-selector` in both, and the trigger
has no `aria-labelledby`.

- [ ] **Step 3: Generate the id and switch to `aria-labelledby`**

Follow the shape `checkbox/component.rb:51` already uses:

```ruby
      def label_id
        @label_id ||= "shadcn-theme-selector-#{SecureRandom.hex(4)}"
      end
```

Give the `Label` that id, drop its `for:`, and pass
`"aria-labelledby" => label_id` to the trigger instead of the hardcoded `id:`.

- [ ] **Step 4: Widen the snapshot normaliser — this is not optional**

`spec/snapshot_spec.rb:24` flattens generated ids so goldens stay stable, and
it currently knows only two prefixes:

```ruby
    html.gsub(/\b(shadcn-(?:checkbox|switch|theme-selector)-)[0-9a-f]{8}\b/, '\1x')
```

Without this the theme selector's snapshot differs on every run and the suite
fails nondeterministically — which is worse than failing, because the first
person to see it will re-run and get a different answer.

- [ ] **Step 5: Green, regenerate, verify determinism**

```bash
bundle exec rspec spec/components/shadcn/theme_selector_spec.rb   # expect PASS
SNAPSHOTS=overwrite bundle exec rspec spec/snapshot_spec.rb
bundle exec rspec spec/snapshot_spec.rb
bundle exec rspec spec/snapshot_spec.rb
```

Both plain runs must pass. Two consecutive passes is the check that the
normaliser actually caught the new id.

- [ ] **Step 6: Suite, rubocop, todo, commit**

```bash
bundle exec rake && bin/rubocop
```

Remove the *Two components name their trigger differently* entry.

```bash
git add -A app/components/shadcn/theme_selector spec .claude/docs/todo.md
git commit -m "Stop ThemeSelector hardcoding a DOM id

Two on one page produced duplicate ids and a label naming only the
first — and the gallery layout already carries one, so a preview was
enough to collide. Generated per instance now, in the shape checkbox and
switch already use, and the snapshot normaliser widened to match or the
goldens would differ every run.

It also names its trigger with aria-labelledby now, following the
FormBuilder. The argument for <label for> was click-to-focus, and this
label is sr-only."
```

---

### Task 6: Stop the controllers rewriting ARIA the server already rendered

**Files:**
- Modify: `app/javascript/shadcn/controllers/{select,popover,dialog,dropdown_menu}_controller.js`
- Modify: `.claude/docs/todo.md`

Each controller re-sets on `connect()` attributes the Ruby already wrote at
render — `select/trigger/component.rb:47-48` emits `aria-expanded="false"` and
`aria-autocomplete="none"`, and `select_controller.js:34-35` writes them again.
Two places to drift, and after a `turbo:morph` the server's version is the one
that survives anyway.

**Not everything there is redundant.** Keep:

- any write whose value comes from a JS-generated id (`aria-controls` pointing
  at `this.contentTarget.id`), because the server does not know it;
- every write inside an open/close handler, which is state, not initial markup.

- [ ] **Step 1: Delete every candidate, then let the suite tell you**

Delete all the `setAttribute` calls in the four `connect()` methods except
those inside open/close handlers. Do not reason first — delete, then measure.

```bash
bundle exec rspec spec/system spec/stimulus_contract_spec.rb
```

What fails was load-bearing. Restore exactly those, and record in your report
which ones failed and which spec caught them.

- [ ] **Step 2: Justify every deletion that survived**

The suite passing is *not* sufficient evidence, and this step is the one that
makes the inversion safe. A write can be both non-redundant and uncovered — no
spec fails, and the attribute is simply gone.

So for each `setAttribute` you left deleted, **cite the Ruby that emits the
same attribute with the same value**, as `file.rb:line`. Put the citations in
your report as a table: controller, attribute, Ruby source.

Any attribute you cannot cite is a real gap, not a redundancy. Restore it, and
say so in your report — that is a finding about the port, not a failure of this
task.

- [ ] **Step 3: Comment what stays and why**

Where a write survives for a reason that is not obvious from reading it, say
so. `aria-controls` in particular: it points at an id the JS generates, so the
server cannot emit it.

- [ ] **Step 4: Suite, rubocop, todo, commit**

```bash
bundle exec rake && bin/rubocop
```

Remove the *ARIA is set twice* entry.

```bash
git add -u
git commit -m "Stop the controllers rewriting ARIA the server rendered

Four controllers re-set attributes on connect that the Ruby already
emits, which is two places to drift — and after a turbo:morph the
server's version is what survives. Writes that depend on a JS-generated
id, and writes inside open/close handlers, stay."
```

---

### Task 7: Share the typeahead, annotate the divergence

**Files:**
- Create: `app/javascript/shadcn/typeahead.js`
- Modify: `app/javascript/shadcn/controllers/{select,dropdown_menu}_controller.js`
- Modify: `.claude/docs/todo.md`

The two controllers share around 60 near-identical lines across roving focus
and typeahead. The differences are deliberate — **dropdown wraps around, select
clamps** — and nothing says so, which is the actual defect.

Extract only what is byte-identical. A shared roving-focus helper would need a
parameter for the wrap-versus-clamp difference, and a parameter per divergence
is how shared code becomes configuration.

- [ ] **Step 1: Establish what is actually identical**

Diff the two regions:

```bash
diff <(sed -n '/typeahead/,/^  }/p' app/javascript/shadcn/controllers/select_controller.js) \
     <(sed -n '/typeahead/,/^  }/p' app/javascript/shadcn/controllers/dropdown_menu_controller.js)
```

Report what came back. **If the typeahead halves are not identical, extract
nothing** and do Step 4 only — the annotation is the part that carries the
value, and a "nearly identical" extraction is the thing this task exists to
avoid.

- [ ] **Step 2: Extract the identical part**

Create `app/javascript/shadcn/typeahead.js` holding what the diff showed to be
the same, with a comment saying what it is for and what it deliberately does
*not* cover. Import it in both controllers and delete the duplicated bodies.

- [ ] **Step 3: Annotate the divergence where it lives**

At the roving-focus code in each controller, a comment naming the difference
and why it exists — dropdown menus wrap because a menu is a cycle, a listbox
clamps because a list has ends. Say it in both places; someone reading one will
not have the other open.

- [ ] **Step 4: Run the behaviour specs**

```bash
bundle exec rspec spec/system/select_spec.rb spec/system/dropdown_menu_spec.rb spec/stimulus_contract_spec.rb
```

Expected: PASS. Both suites exercise typeahead and arrow keys, including the
wrap and the clamp.

- [ ] **Step 4: Suite, rubocop, todo, commit**

```bash
bundle exec rake && bin/rubocop
```

Remove the *`select_controller` and `dropdown_menu_controller` share ~60
near-identical lines* entry.

```bash
git add -A app/javascript/shadcn .claude/docs/todo.md
git commit -m "Share the typeahead, and say why the rest differs

Only the byte-identical part is extracted. Roving focus stays separate
because dropdown wraps and select clamps, and a shared version would
need a parameter per divergence — which is how shared code becomes
configuration. The divergence is now named in both files."
```

---

### Task 8: A layer keeps following its anchor while it fades

**Files:**
- Modify: `app/javascript/shadcn/floating.js`
- Modify: `spec/system/exit_animation_spec.rb`
- Modify: `.claude/docs/todo.md`

`hide()` removes the scroll and resize listeners immediately, so a layer
scrolled during its exit animation detaches from its trigger for the length of
it. Both `reposition()` and `applyPosition()` return early on `this.open`, which
is why it needs a second piece of state rather than a moved line.

- [ ] **Step 1: Write the failing spec**

In `spec/system/exit_animation_spec.rb`, inside the floating-layer block:

```ruby
    it "keeps following its anchor while it fades" do
      force_animations(content, duration: "3s")
      trigger.click
      expect(page).to have_css(content)

      before_scroll = page.evaluate_script(
        "document.querySelector('#{content}').getBoundingClientRect().top"
      )
      press(:escape)
      page.execute_script("window.scrollBy(0, 120)")

      after_scroll = page.evaluate_script(
        "document.querySelector('#{content}').getBoundingClientRect().top"
      )

      expect(after_scroll).not_to eq(before_scroll)
    end
```

The preview must be tall enough to scroll. If it is not, give the example a
wrapper with `min-height` rather than changing the shared preview.

- [ ] **Step 2: Run it and watch it fail**

Run: `bundle exec rspec spec/system/exit_animation_spec.rb -e "keeps following"`
Expected: FAIL — the two measurements are equal, because the layer stopped
tracking at `hide()`.

- [ ] **Step 3: Add the flag**

Introduce `this.mounted`, true from `mount()` until `dismount()`, and have
`reposition()` and `applyPosition()` guard on it instead of `this.open`. Move
the listener removal from `hide()` into `dismount()`. Leave `this.open` meaning
exactly what it means now — whether the layer is logically open — because
`show()`, `toggle()` and the dismiss layer all read it.

- [ ] **Step 4: Green, then the regression set**

```bash
bundle exec rspec spec/system/exit_animation_spec.rb spec/system/overlays_spec.rb \
  spec/system/select_spec.rb spec/system/dropdown_menu_spec.rb spec/system/turbo_spec.rb
```

Expected: PASS. A failure in `turbo_spec` means the listeners now outlive the
element — check `destroy()` still reaches `dismount()`.

- [ ] **Step 4: Suite, rubocop, todo, commit**

```bash
bundle exec rake && bin/rubocop
```

Remove the *A layer stops following its anchor while it fades* entry, and
correct the paragraph in `.claude/docs/decisions/02-javascript.md` that records
this as a deliberate loss — it is no longer given up.

```bash
git add -A app/javascript/shadcn spec .claude/docs
git commit -m "Keep a floating layer on its anchor while it fades

hide() dropped the scroll and resize listeners immediately, so a layer
scrolled during its exit detached from its trigger. Positioning now
guards on a mounted flag rather than on open, which is what reposition()
and applyPosition() both returned early on."
```

---

### Task 9: Closing content leaves the tab order

**Files:**
- Modify: `app/javascript/shadcn/animation.js`
- Modify: `spec/system/exit_animation_spec.rb`
- Modify: `.claude/docs/todo.md`, `.claude/docs/decisions/02-javascript.md`

`hidden` is what takes closing content out of the tab order, and that now waits
for the animation. `[data-slot][data-exiting]` stops clicks — and not even
everywhere, since the accordion is excluded — but it stops neither Tab nor a
screen reader. For a few hundred milliseconds a dismissed dialog is still
reachable.

- [ ] **Step 1: Write the failing spec**

```ruby
    it "leaves the tab order as soon as it starts closing" do
      force_animations(content, duration: "3s")
      trigger.click
      expect(page).to have_css(content)

      press(:escape)

      expect(page.evaluate_script(
        "document.querySelector('#{content}').matches('[inert]')"
      )).to be(true)
    end
```

- [ ] **Step 2: Run it and watch it fail**

Expected: FAIL — nothing sets `inert`.

- [ ] **Step 3: Set `inert` alongside `data-exiting`**

In `ExitQueue#defer`, where `element.dataset.exiting` is set, also set
`element.inert = true`; clear both in `flush` and in `cancel`. A comment saying
why `inert` and `data-exiting` are not the same thing: one removes the element
from the tab order and the accessibility tree, the other is a CSS hook with a
deliberate accordion exception.

- [ ] **Step 4: Check the reopen path**

Reopening mid-exit must clear `inert`, or a reopened dialog is unreachable by
keyboard. The existing "keeps the reopened content on screen" examples do not
assert this — extend the reopen example to assert `inert` is gone, and verify
by mutation that removing the clear from `cancel` fails it.

- [ ] **Step 5: Regression set**

```bash
bundle exec rspec spec/system spec/system/accessibility_spec.rb
```

Expected: PASS. Watch `accessibility_spec` in particular — `inert` on a
container while a layer is open would hide it from axe.

- [ ] **Step 6: Suite, rubocop, todo, commit**

```bash
bundle exec rake && bin/rubocop
```

Remove the *Closing content stays focusable while it fades* entry, and update
`02-javascript.md` where it says the marker "stops clicks everywhere except the
accordion" — Tab is now handled separately.

```bash
git add -A app/javascript/shadcn spec .claude/docs
git commit -m "Take closing content out of the tab order

hidden is what did that, and it now waits for the animation, so a
dismissed dialog stayed reachable by keyboard and by screen reader for
the length of the fade. data-exiting is a CSS hook and never touched
either; inert is the thing that does."
```

---

### Task 10: Say what the `!important` rules add up to

**Files:**
- Modify: `.claude/docs/decisions/02-javascript.md`
- Modify: `README.md`
- Modify: `.claude/docs/todo.md`

Four rules carry `!important` from inside a cascade layer: `[data-slot][hidden]`,
`[data-slot][data-exiting]`, and the two `animate-accordion-*` overrides. Each
says in place why it is `!important`. Nothing says what the set of them imposes
on a host — that a layered `!important` beats an unlayered one at any
specificity, so an application cannot switch one off with an `!important` of its
own, only inline or from a layer declared earlier.

`02-javascript.md` records this only from the side that bit the test harness.

- [ ] **Step 1: Write the section**

Add to `02-javascript.md`, under the cascade-layer trap, a short section listing
the four rules, stating the constraint in one sentence, and giving the two
escapes that do work — an inline style, or a layer declared before Tailwind's.
Say which rules a host might plausibly want to override and why they exist, so
the reader can tell "deliberate" from "in your way".

- [ ] **Step 2: Give hosts the short version in the README**

The decision docs are for contributors. A host hitting this reads the README:
two or three sentences under theming or customisation, with the inline escape.

- [ ] **Step 3: Verify the claim before publishing it**

The section asserts something about the cascade. Confirm it against the built
bundle rather than restating it from memory:

```bash
grep -n "important" test/dummy/app/assets/builds/tailwind.css | head
```

Check the four rules are where the text says, and that each sits inside a layer.
Report what you found. If any of them is unlayered, the text is wrong and needs
correcting, not softening.

- [ ] **Step 4: Todo and commit**

```bash
bin/rubocop
```

Remove the *The gem's `!important` rules cannot be overridden the ordinary way*
entry.

```bash
git add -A .claude/docs README.md
git commit -m "Write down what the !important rules impose on a host

Each rule says why it is !important. None of them says what the set adds
up to: a layered !important beats an unlayered one at any specificity, so
a host can only override with an inline style or an earlier layer."
```

---

## Self-review

**Coverage.** Eleven todo entries, ten tasks: Task 1 closes two, the rest one
each. `--animate-caret-blink` is deliberately excluded and its entry stays, with
the reason recorded in the design above.

**Independence.** No task consumes anything another produces. Task 1 and Task 2
both touch the spec suite but different files; Tasks 8 and 9 both touch the exit
path but different files. Any task can be dropped without stranding another.

**The one ordering that matters.** Tasks 1 and 2 change what the suite *is*, and
every later task's verification runs through it — so they go first. Beyond that
the order is by risk, lowest first.

**Two tasks can legitimately end in "did less than planned",** and both say so
in place rather than forcing the outcome: Task 1 stops if breaking a preview
does not fail `snapshot_spec`, and Task 7 extracts nothing if the two typeahead
halves are not byte-identical. A reviewer should read those as the task working,
not failing.

**Naming consistency.** `Shadcn::Icon.register` / `.registered`, `renders_many
:items` with `with_item`, `label_id`, `this.mounted`, `element.inert` — each
used with one meaning throughout.

**What this plan does not do.** No new component, nothing from the 23-item
backlog, and none of the three release blockers — the GitHub repository, the
version decision, and the unproven CI.
