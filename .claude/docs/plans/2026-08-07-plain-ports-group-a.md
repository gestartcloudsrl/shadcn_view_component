# Vendoring, and the four markup-only ports

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the 27 unported shadcn sources into `vendor/`, teach `parity_spec`
to tell "vendored" from "ported", and port the four components that are markup
and nothing else.

**Architecture:** Vendoring first, because without the TSX there is no parity
reference and the repo's one hard constraint cannot be honoured or checked. Then
one task per component, each moving its name from `not_yet_ported` to `ports`
and gaining a preview, which is what enrols it in three suites at once.

**Tech Stack:** Rails engine, ViewComponent + `view_component-contrib`
StyleVariants, Tailwind 4, RSpec.

**Read first:** the `viewcomponent-guideline` skill in `.claude/skills/` — the
`part` macro, the attribute precedence, and where this repo departs from both
the Evil Martians articles and the framework's own guide.

---

## The design

### Why vendoring comes first

`vendor/shadcn/ui/` holds exactly the 34 TSX files of the 34 ported components.
None of the 27 unported ones is there. That directory *is* the parity reference:
`parity_spec` reads the TSX and asserts every Tailwind class React emits appears
in the corresponding Ruby. Port without vendoring and the component has no net;
vendor without porting and the suite breaks, because the spec currently asserts
the two lists are **equal**.

So they land together, and the equality is preserved rather than weakened — an
explicit `not_yet_ported` list. Vendoring a file and forgetting to classify it
still fails, which is the signal that assertion exists to give.

### The revision must not move

Copy from the clone checked out at `607e8a9717fe6ff0d374ba74c651012f9c052534`,
the revision already in `vendor/shadcn/REVISION`. Not `HEAD`. The 27 new files
have to come from the same point in time as the 34 existing ones, or the
reference becomes a mixture of two revisions and a future parity failure no
longer says whether the port drifted or the reference did. `REVISION` does not
change, because the revision does not change.

### Why the class strings are not in this plan

**Deliberate, and it is the one place this plan departs from how plans are
normally written here.** Every Tailwind class string is read from the vendored
TSX at implementation time and copied straight into the Ruby. They are not
transcribed into this document.

Copying them source → plan → Ruby adds a transcription step that can only
introduce errors, on a port whose entire purpose is to be identical to upstream,
and whose `parity_spec` checks exactly those strings. The plan gives structure —
which parts exist, what each is, which have variants, what the traps are. The
strings come from the file.

### What "markup only" was verified to mean

All four were checked for React state before being chosen: **zero
`useState`/`useEffect`/`useContext`/`createContext`/`useRef` across all four
files.** They need no Stimulus controller, which is why
`stimulus_contract_spec` should not move for any task in this plan. If it does,
something was ported that is not what this plan says it is.

---

## Global Constraints

- **1:1 with upstream.** Classes, `data-slot` values and part names come from the
  TSX and are not improved, reordered or renamed.
- **Never split a Tailwind class string across a `\` line continuation.**
  Tailwind scans source text, so half a token generates no CSS. Concatenate
  whole tokens: `"foo bar " \` then `"baz"`.
- **`Shadcn::` namespacing.** Every family nests under it; a host's own `Item` or
  `Empty` model must not collide.
- **Attribute precedence is `data-slot` < component defaults < caller.** What a
  subclass passes to `super` in `#element_attributes` is a *default* despite
  arriving as a keyword splat. `class` and `data-action` concatenate.
- **Generated files are never hand-edited:** `lib/shadcn_view_component/themes.rb`,
  `app/assets/stylesheets/shadcn-themes.css`, and the `shadcn-tokens` block in
  `shadcn.css`. Nothing here touches them.
- **A part that is only an element with a `data-slot` and fixed classes is
  declared with `part` on the family module.** It earns its own `component.rb`
  only once it has variants, slots, extra markup, or attributes computed from
  its arguments.
- **Variant keys keep upstream's spelling.** Keys that are not valid Ruby method
  names are declared with `send(:"icon-xs") { … }`, as `button/component.rb`
  already does.
- **Previews are fixtures, not decoration.** `snapshot_spec`, `previews_spec` and
  `accessibility_spec` read the preview list off disk. And it is enforced, not
  merely expected: `snapshot_spec`'s "has a preview to snapshot for nearly every
  family" derives every family from `app/components/shadcn/*/component.rb` and
  asserts each has one, with `icon` as the single allowed exception. **Creating
  a family root without a preview fails the suite.** Nested part components
  (`empty/media/component.rb`) are not matched by that glob and need none.
- **Golden snapshots live in `spec/fixtures/snapshots/`**, one file per preview
  template, named `<family>-<example>.html`. Regenerate with
  `SNAPSHOTS=overwrite bundle exec rspec spec/snapshot_spec.rb`.
- **After every task:** the task's own specs, then `bundle exec rake`, then
  `bin/rubocop`.

---

## File Structure

| file | responsibility |
|---|---|
| `vendor/shadcn/ui/*.tsx` | **27 new.** the parity reference |
| `spec/parity_spec.rb` | gains `not_yet_ported`; the equality assertion is preserved |
| `app/components/shadcn/<family>.rb` | **new, one per family.** `part` declarations, a *sibling* of the family directory |
| `app/components/shadcn/<family>/component.rb` | **new.** the family root |
| `app/components/shadcn/<family>/<part>/component.rb` | **new.** only the parts with variants |
| `app/components/shadcn/<family>/preview.rb` + `previews/*.html.erb` | **new.** the fixtures |
| `.claude/docs/todo.md` | the corrected classification of what is left |

---

### Task 1: Vendor the 27, and teach parity the difference

**Files:**
- Create: `vendor/shadcn/ui/{27 files}.tsx`
- Modify: `spec/parity_spec.rb`
- Modify: `.claude/docs/todo.md`

**Interfaces:**
- Produces: a local `not_yet_ported` array in `parity_spec.rb`, from which Tasks
  2-5 each delete one entry while adding the matching `ports` entry.

**Prerequisite:** a clone of `shadcn-ui/ui` exists at `/tmp/shadcn-ui`, checked
out at `607e8a9717fe6ff0d374ba74c651012f9c052534`. Verify with
`git -C /tmp/shadcn-ui rev-parse HEAD` before copying. If it is absent or at a
different revision, **stop and report** — do not re-clone at `HEAD`.

- [ ] **Step 1: Copy only the files that are missing**

```bash
SRC=/tmp/shadcn-ui/apps/v4/registry/new-york-v4/ui
DST=vendor/shadcn/ui

for f in "$SRC"/*.tsx; do
  name=$(basename "$f")
  [ -e "$DST/$name" ] || cp "$f" "$DST/$name"
done

ls "$DST"/*.tsx | wc -l   # expect 61
git status --short vendor/shadcn/ui | wc -l   # expect 27, all additions
```

Expected: 61 files present, 27 of them new, **zero modifications to existing
files**. A modified existing file means the clone is at the wrong revision —
stop and report.

- [ ] **Step 2: Watch parity fail**

Run: `bundle exec rspec spec/parity_spec.rb -e "ports every component vendored for comparison"`

Expected: FAIL. The example asserts `ports.keys.sort == ShadcnSource.vendored_components`
and there are now 27 vendored names with no port.

- [ ] **Step 3: Add the backlog list**

In `spec/parity_spec.rb`, after the `ports` hash and before `inherits`:

```ruby
  # Vendored for reference but not ported yet. Kept here rather than in a
  # document so the two lists cannot drift: adding a TSX without deciding which
  # side it belongs on fails the example below, which is the whole point of it.
  not_yet_ported = %w[
    attachment bubble button-group calendar carousel chart combobox command
    context-menu direction drawer empty form hover-card input-group input-otp
    item marker menubar message message-scroller navigation-menu resizable
    scroll-area sidebar slider sonner
  ].freeze
```

Then change the example to keep the equality:

```ruby
  it "accounts for every component vendored for comparison" do
    expect((ports.keys + not_yet_ported).sort).to eq(ShadcnSource.vendored_components)
  end
```

- [ ] **Step 4: Run it green, and prove it still bites**

```bash
bundle exec rspec spec/parity_spec.rb
```
Expected: PASS.

Then verify the tripwire survives, because an assertion that cannot fail is
worse than none:

```bash
touch vendor/shadcn/ui/zzz-probe.tsx
bundle exec rspec spec/parity_spec.rb -e "accounts for every component"
# expect FAIL naming zzz-probe
rm vendor/shadcn/ui/zzz-probe.tsx
```

Put both outputs in your report.

- [ ] **Step 5: Correct the todo's classification**

`.claude/docs/todo.md` groups the 27 as "Heavy JS" / "Plain ports, no blocker" /
"AI chat set". Reading the sources shows that grouping is wrong in four ways.
Rewrite the section to what the imports actually say:

- **Markup only** (8): `empty`, `input-group`, `button-group`, `item`,
  `message`, `bubble`, `attachment`, `marker` — no library, `radix-ui` only for
  `Slot`. Four of these were filed under "AI chat set", which implied difficulty
  they do not have.
- **Radix behaviour to reimplement** (7): `hover-card`, `scroll-area`, `slider`,
  `navigation-menu`, `context-menu`, `menubar`, `direction`.
- **Blocked by a third-party npm package** (10): `drawer`→vaul,
  `chart`→recharts, `command`→cmdk, `carousel`→embla-carousel-react,
  `input-otp`, `sonner`, `resizable`→react-resizable-panels,
  `calendar`→react-day-picker, `combobox`→**@base-ui/react**,
  `message-scroller`→**@shadcn/react/message-scroller**. The last two are new
  blockers the list did not record; note that `combobox` has moved off Radix to
  Base UI, so reimplementing it means tracking a second headless API.
- **Cases of their own** (2): `form`→react-hook-form, whose Rails answer is the
  existing FormBuilder plus the already-ported `field`; and `sidebar`, 726 lines
  composing sheet, tooltip, button, input, separator and skeleton.

Note in passing that `command/combobox` was one line for two files, which is why
the total still came to 27.

- [ ] **Step 6: Full suite, then commit**

```bash
bundle exec rake && bin/rubocop
git add vendor/shadcn/ui spec/parity_spec.rb .claude/docs/todo.md
git commit -m "Vendor the 27 unported sources, and classify them by what they import

parity_spec asserted that vendored and ported were the same list, so
sources could not arrive before their ports. It now asserts the two
account for the vendored set between them, which keeps the tripwire:
adding a TSX without deciding where it belongs still fails.

The todo's grouping turned out wrong in four ways — four of the six
'AI chat set' components are the easiest in the backlog, three of the
thirteen 'no blocker' ones have blockers, and combobox and
message-scroller are blocked by dependencies nobody had recorded."
```

---

### Task 2: Empty

Six parts, one with variants. The smallest of the four, and the one to get the
family shape right on.

**Files:**
- Create: `app/components/shadcn/empty.rb`
- Create: `app/components/shadcn/empty/component.rb`
- Create: `app/components/shadcn/empty/media/component.rb`
- Create: `app/components/shadcn/empty/preview.rb`, `previews/default.html.erb`
- Modify: `spec/parity_spec.rb`

**Interfaces:**
- Consumes: `not_yet_ported` from Task 1.
- Produces: `Shadcn::Empty::Component` and its parts; the pattern Tasks 3-5 follow.

**Source:** `vendor/shadcn/ui/empty.tsx`. Read it before writing anything.

**The structure, and one trap:**

| TSX function | `data-slot` | shape |
|---|---|---|
| `Empty` | `empty` | family root, `<div>` |
| `EmptyHeader` | `empty-header` | `part` |
| `EmptyMedia` | **`empty-icon`** | `component.rb` — has a `variant` cva |
| `EmptyTitle` | `empty-title` | `part` |
| `EmptyDescription` | `empty-description` | `part`, `<p>` |
| `EmptyContent` | `empty-content` | `part` |

**The trap:** `EmptyMedia` renders `data-slot="empty-icon"`. The function name
and the slot do not match, and the slot is what matters — it is what the CSS and
the sibling selectors key on. Name the Ruby part after the function (`Media`),
give it the slot upstream emits (`empty-icon`).

- [ ] **Step 1: Write the failing parity example**

Move `empty` out of `not_yet_ported` and into `ports` in `spec/parity_spec.rb`:

```ruby
    "empty" => "empty",
```

- [ ] **Step 2: Run it and watch it fail**

Run: `bundle exec rspec spec/parity_spec.rb -e "empty.tsx"`
Expected: FAIL — every class the TSX emits is reported missing, because no Ruby
carries them yet.

- [ ] **Step 3: Write the family file**

`app/components/shadcn/empty.rb` — a **sibling** of `empty/`, not inside it.
Declare the four slot-only parts with `part`, taking each `classes:` string
verbatim from the TSX. `EmptyDescription` renders a `<p>`, so it needs
`tag: :p`.

```ruby
# frozen_string_literal: true

module Shadcn
  # The parts of the Empty family that are just an element with a `data-slot`
  # and a fixed set of classes.
  module Empty
    extend Parts

    part :header, slot: "empty-header", classes: "…"        # from empty.tsx
    part :title, slot: "empty-title", classes: "…"
    part :description, slot: "empty-description", tag: :p, classes: "…"
    part :content, slot: "empty-content", classes: "…"
  end
end
```

- [ ] **Step 4: Write the root and the one part with variants**

`empty/component.rb`: `slot_name :empty`, a `style` block with only a `base`.

`empty/media/component.rb`: `slot_name :"empty-icon"`, a `style` block with
`base`, `variants { variant { … } }` and `defaults { { variant: :default } }`,
plus:

```ruby
def style_variants
  { variant: @variant }
end
```

and an `initialize` that takes `variant:` with upstream's default. Follow
`app/components/shadcn/button/component.rb` for the exact shape.

- [ ] **Step 5: Write the preview**

`empty/preview.rb`:

```ruby
# frozen_string_literal: true

module Shadcn
  module Empty
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end
    end
  end
end
```

`empty/previews/default.html.erb` should exercise every part at least once,
because the preview is what the snapshot and accessibility suites see. Model it
on upstream's own example composition: media, title, description, content.

- [ ] **Step 6: Green the parity example, then generate the snapshot**

```bash
bundle exec rspec spec/parity_spec.rb -e "empty.tsx"      # expect PASS
SNAPSHOTS=overwrite bundle exec rspec spec/snapshot_spec.rb
```

**Then read the generated HTML before trusting it.** A snapshot you generated
and then asserted against proves only that rendering is deterministic. Open
`spec/fixtures/snapshots/empty-default.html` and check it against `empty.tsx` by
eye: the right `data-slot` on the right element, the classes present,
`empty-icon` where `EmptyMedia` is. Say in your report that you did this and
what you compared.

- [ ] **Step 7: Full suite, rubocop, commit**

```bash
bundle exec rake && bin/rubocop
```

`stimulus_contract_spec` must not move — this component has no JavaScript.

```bash
git add app/components/shadcn/empty.rb app/components/shadcn/empty spec/parity_spec.rb spec/
git commit -m "Port empty

Six parts, one of them with a variant. Note EmptyMedia emits
data-slot=\"empty-icon\": the function name and the slot differ upstream,
and the slot is what the sibling selectors key on."
```

---

### Task 3: ButtonGroup

Three parts. Introduces two things Task 2 did not have: a part with **no
`data-slot` at all**, and a part that wraps an already-ported component.

**Files:**
- Create: `app/components/shadcn/button_group.rb`
- Create: `app/components/shadcn/button_group/component.rb`
- Create: `app/components/shadcn/button_group/text/component.rb`
- Create: `app/components/shadcn/button_group/separator/component.rb`
- Create: `app/components/shadcn/button_group/preview.rb`, `previews/default.html.erb`
- Modify: `spec/parity_spec.rb`

**Source:** `vendor/shadcn/ui/button-group.tsx`. Note the directory is
`button_group` while the parity key is `button-group` — the hash maps one to the
other.

| TSX function | `data-slot` | shape |
|---|---|---|
| `ButtonGroup` | `button-group` | root, `orientation` cva |
| `ButtonGroupText` | **none** | `component.rb`, supports `asChild` |
| `ButtonGroupSeparator` | `button-group-separator` | `component.rb`, wraps `Separator` |

**Two traps:**

`ButtonGroupText` emits **no `data-slot`**. Do not invent one. `slot_name` is
simply not called on it; `element_attributes` drops the key when it is `nil`.
It supports `asChild`, which is this repo's `as:` — already handled by the base
class, so it needs no special code.

`ButtonGroupSeparator` renders the ported `Separator` with its own classes and
`orientation`, rather than a bare element. Compose it: render
`Shadcn::Separator::Component` from `#call`, passing the classes through. Read
how `pagination` borrows `Button`'s classes for the established way to do this.

- [ ] **Step 1: Move `button-group` from `not_yet_ported` to `ports`**

```ruby
    "button-group" => "button_group",
```

- [ ] **Step 2: Run and watch it fail**

Run: `bundle exec rspec spec/parity_spec.rb -e "button-group.tsx"`
Expected: FAIL, every class reported missing.

- [ ] **Step 3: Write the family file, the root and the two parts**

`button_group.rb` declares nothing with `part` — all three parts have behaviour,
so the family file may not be needed at all. **If it declares nothing, do not
create it.** An empty module file is noise.

Root: `slot_name :"button-group"`, `style` with `base` and
`variants { orientation { horizontal { … } vertical { … } } }`,
`defaults { { orientation: :horizontal } }`, plus `style_variants` and an
`initialize` taking `orientation:`.

- [ ] **Step 4: Write the preview**

`previews/default.html.erb` should show a horizontal group of buttons, a
`ButtonGroupText`, and a separator between two buttons. Add a `vertical` example
so the second orientation is covered by the snapshot.

`preview.rb` gets a method per example:

```ruby
def default
  render_with_template
end

def vertical
  render_with_template
end
```

with `previews/vertical.html.erb` alongside.

- [ ] **Step 5: Green, snapshot, and read the snapshot**

```bash
bundle exec rspec spec/parity_spec.rb -e "button-group.tsx"   # expect PASS
SNAPSHOTS=overwrite bundle exec rspec spec/snapshot_spec.rb
```

Read the generated HTML against the TSX. Specifically confirm
`ButtonGroupText` rendered **without** a `data-slot`, and that the separator is
a real `Separator` with the group's own classes on it.

- [ ] **Step 6: Full suite, rubocop, commit**

```bash
bundle exec rake && bin/rubocop
git add app/components/shadcn/button_group spec/
git add app/components/shadcn/button_group.rb 2>/dev/null || true
git commit -m "Port button-group

ButtonGroupText emits no data-slot upstream and does not get one here.
ButtonGroupSeparator renders the ported Separator rather than a bare
element, the way pagination borrows Button's classes."
```

---

### Task 4: InputGroup

Six parts, two cva blocks, and the most composition of the four: three of its
parts render already-ported components.

**Files:**
- Create: `app/components/shadcn/input_group.rb` (only if any part is slot-only)
- Create: `app/components/shadcn/input_group/component.rb`
- Create: `app/components/shadcn/input_group/addon/component.rb`
- Create: `app/components/shadcn/input_group/button/component.rb`
- Create: `app/components/shadcn/input_group/text/component.rb`
- Create: `app/components/shadcn/input_group/input/component.rb`
- Create: `app/components/shadcn/input_group/textarea/component.rb`
- Create: `app/components/shadcn/input_group/preview.rb`, `previews/default.html.erb`
- Modify: `spec/parity_spec.rb`

**Source:** `vendor/shadcn/ui/input-group.tsx`. Parity key `input-group`,
directory `input_group`.

| TSX function | `data-slot` | shape |
|---|---|---|
| `InputGroup` | `input-group` | root, `<div>` |
| `InputGroupAddon` | `input-group-addon` | `align` cva |
| `InputGroupButton` | none of its own | renders ported `Button`, `size` cva |
| `InputGroupText` | **none** | `<span>` |
| `InputGroupInput` | `input-group-control` | renders ported `Input` |
| `InputGroupTextarea` | **`input-group-control`** | renders ported `Textarea` |

**Three traps:**

**Two different parts share one `data-slot`.** `InputGroupInput` and
`InputGroupTextarea` both emit `input-group-control`, because the root's
`has-[[data-slot=input-group-control]:focus-visible]:…` classes have to match
either. This is correct upstream and must be reproduced; do not disambiguate
them.

**Variant keys are hyphenated.** `align` has `inline-start`, `inline-end`,
`block-start`, `block-end`; `size` has `icon-xs` and `icon-sm`. Declare them
with `send(:"inline-start") { … }`, as `button/component.rb` does — the keys have
to stay identical to the TSX's.

**`InputGroupButton` forces defaults on the component it wraps**: `type="button"`,
`variant="ghost"`, `size="xs"`, plus a `data-size` attribute carrying its own
size. Those are *component defaults*, so they must rank below anything the
caller passes — which is what passing them through `super` in
`#element_attributes` achieves. Getting this backwards makes the button
un-restylable.

- [ ] **Step 1: Move `input-group` from `not_yet_ported` to `ports`**

```ruby
    "input-group" => "input_group",
```

- [ ] **Step 2: Run and watch it fail**

Run: `bundle exec rspec spec/parity_spec.rb -e "input-group.tsx"`
Expected: FAIL.

- [ ] **Step 3: Write the root and the six parts**

Follow Task 2's shapes. For the three composing parts, render the ported
component from `#call` and pass the part's own classes as a *default* so the
caller still wins.

- [ ] **Step 4: Write the preview**

Cover, at minimum: an input with a leading addon and a trailing button, and a
textarea variant. Every `align` value should appear across the examples, since
`snapshot_spec` only sees what a preview renders.

- [ ] **Step 5: Green, snapshot, read it**

```bash
bundle exec rspec spec/parity_spec.rb -e "input-group.tsx"    # expect PASS
SNAPSHOTS=overwrite bundle exec rspec spec/snapshot_spec.rb
```

Read the output: confirm both the input and the textarea carry
`data-slot="input-group-control"`, and that the button kept `variant=ghost`
unless the preview overrode it.

- [ ] **Step 6: Full suite, rubocop, commit**

```bash
bundle exec rake && bin/rubocop
git add app/components/shadcn/input_group spec/
git add app/components/shadcn/input_group.rb 2>/dev/null || true
git commit -m "Port input-group

InputGroupInput and InputGroupTextarea deliberately share
data-slot=\"input-group-control\": the root's has-[…] focus classes match
either, so disambiguating them would break the focus ring.

InputGroupButton's type/variant/size are component defaults and rank
below the caller's, which is what keeps it restylable."
```

---

### Task 5: Item

Ten parts, two cva blocks. The largest, and the last.

**Files:**
- Create: `app/components/shadcn/item.rb`
- Create: `app/components/shadcn/item/component.rb`
- Create: `app/components/shadcn/item/media/component.rb`
- Create: `app/components/shadcn/item/separator/component.rb`
- Create: `app/components/shadcn/item/preview.rb`, `previews/default.html.erb`
- Modify: `spec/parity_spec.rb`

**Source:** `vendor/shadcn/ui/item.tsx`.

| TSX function | `data-slot` | shape |
|---|---|---|
| `Item` | `item` | root, `variant` + `size` cva, `asChild` |
| `ItemGroup` | `item-group` | `part` |
| `ItemSeparator` | `item-separator` | `component.rb`, wraps `Separator` |
| `ItemMedia` | `item-media` | `variant` cva |
| `ItemContent` | `item-content` | `part` |
| `ItemTitle` | `item-title` | `part` |
| `ItemDescription` | `item-description` | `part`, `<p>` |
| `ItemActions` | `item-actions` | `part` |
| `ItemHeader` | `item-header` | `part` |
| `ItemFooter` | `item-footer` | `part` |

Six of the ten are `part` lines. That ratio is why the macro exists.

**One trap:** the root's classes include `group/item`, and `ItemMedia`'s include
`group-has-[[data-slot=item-description]]/item:…`. Those are one mechanism: a
named Tailwind group whose descendant selector reaches back up. Both halves must
be copied exactly or the media stops shifting when a description is present, and
nothing will fail — `parity_spec` checks the classes exist, not that they still
refer to each other.

- [ ] **Step 1: Move `item` from `not_yet_ported` to `ports`**

```ruby
    "item" => "item",
```

- [ ] **Step 2: Run and watch it fail**

Run: `bundle exec rspec spec/parity_spec.rb -e "item.tsx"`
Expected: FAIL.

- [ ] **Step 3: Write the family file with its six parts**

`app/components/shadcn/item.rb`, a sibling of `item/`, following `card.rb`'s
shape exactly. `ItemDescription` is a `<p>`, so `tag: :p`.

- [ ] **Step 4: Write the root and the two parts with behaviour**

Root: `variant` (`default`/`outline`/`muted`) and `size` (`default`/`sm`), with
`asChild` handled by the base class's `as:`.

`ItemSeparator` wraps the ported `Separator`, as `ButtonGroupSeparator` did in
Task 3 — reread that component rather than reinventing it.

- [ ] **Step 5: Write the preview**

The default should be a realistic list: an `ItemGroup` holding two or three
`Item`s, each with media, title, description and actions, and an `ItemSeparator`
between them. Add examples for the `outline` and `muted` variants so the
snapshot covers them.

- [ ] **Step 6: Green, snapshot, read it**

```bash
bundle exec rspec spec/parity_spec.rb -e "item.tsx"     # expect PASS
SNAPSHOTS=overwrite bundle exec rspec spec/snapshot_spec.rb
```

Read the output: confirm `group/item` is on the root and the
`group-has-[…]/item:` classes are on the media, unaltered.

- [ ] **Step 7: Full suite, rubocop, commit**

```bash
bundle exec rake && bin/rubocop
git add app/components/shadcn/item.rb app/components/shadcn/item spec/
git commit -m "Port item

Six of its ten parts are `part` lines, which is the ratio the macro
exists for. The root's group/item and ItemMedia's
group-has-[[data-slot=item-description]]/item: classes are one mechanism
and only work as a pair — parity checks both exist, not that they still
point at each other."
```

---

### Task 6: Say what is left

**Files:**
- Modify: `.claude/docs/todo.md`
- Modify: `README.md` if it states a component count

- [ ] **Step 1: Update the counts**

Four are ported, so the backlog is 23, not 27, and the "markup only" group is
down to the four chat components. Update the numbers and move the four out.

- [ ] **Step 2: Record the two blockers nobody had named**

If Task 1's rewrite did not already do it, make sure `combobox`'s move to Base
UI and `message-scroller`'s dependency on a shadcn npm package are recorded as
blockers, not as plain ports.

- [ ] **Step 3: Check for a stale count elsewhere**

```bash
grep -rn "27\|34 components\|thirty-four" README.md CLAUDE.md .claude/docs/ | grep -v plans/
```

Fix whatever that finds. Do not change numbers you cannot verify.

- [ ] **Step 4: Full suite, commit**

```bash
bundle exec rake && bin/rubocop
git add .claude/docs/todo.md README.md
git commit -m "Record the four ports and what is left"
```

---

## Self-review

**Design coverage.** Vendoring and the parity change → Task 1; the four ports →
Tasks 2-5; the reclassification → Tasks 1 and 6.

**No class strings in this plan, by design.** Stated at the top with its
justification. Every task instead names its source file and tells the
implementer to read it. If a reviewer flags this as a placeholder, it is the one
place where the answer is "no, deliberately" — the alternative introduces a
transcription step between the source of truth and the code, on exactly the
strings `parity_spec` exists to police.

**Naming consistency.** `not_yet_ported`, `ports`, `part`, `slot_name`,
`style_variants`, `render_with_template` — each used with the same meaning
throughout. Parity keys are hyphenated (`button-group`), directories are
underscored (`button_group`), and the `ports` hash is what maps between them.

**What this plan does not do.** No component with behaviour, nothing blocked by
an npm package, no `sidebar`, no `form`, and none of the four chat components —
they are markup-only too, and deliberately deferred.

**Known risk.** `snapshot_spec` goldens are generated by the implementer and
then asserted against. That proves determinism, not correctness, which is why
every port task has an explicit step to read the generated HTML against the TSX
and report what was compared. A reviewer should treat an unread snapshot as no
coverage at all.
