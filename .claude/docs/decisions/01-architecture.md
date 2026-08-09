# Architecture decisions

Decided 2026-08-05/06, during the initial port.

## Project shape

**Rails engine + `test/dummy` with Lookbook**, rather than a bare
`app/components` directory or a demo app. The gallery is the only way to see
whether a port actually looks like shadcn, and it later became the fixture set
for the snapshot, preview, accessibility and system specs. *(user's call)*

**One ViewComponent class per React part, plus slot sugar** on the parent.
*(user's call)*

**Everything namespaced under `Shadcn::`** — a deviation from the approved plan,
which said top-level `Card::Component`. Zeitwerk cannot have `Shadcn::Card` (an
implicit namespace from `card/`) and a host app's `Card` model coexist, and
`Card`, `Table`, `Field` and `Select` are all common model names. The plan's
intent — one class per part, sidecar layout — is preserved.

**`app/components/shadcn/` not `app/views/components/`.** `app/views` is
ambiguous as an autoload root; `app/components` is ViewComponent's own location
and is picked up by the engine's `app/{*,*/concerns}` glob for free.

## The mapping

**`view_component-contrib`'s `StyleVariants` as the cva port**, and the
`tailwind_merge` gem as `cn()`, wired in through `postprocess_with`. Both are
near-exact equivalents rather than approximations: the
`style { base {} variants {} defaults {} compound() {} }` DSL maps onto cva
one-for-one, and the postprocessor hook is precisely where `cn()` belongs.

**Attribute precedence: `data-slot` < component defaults < caller.** What a
subclass passes to `super` in `#element_attributes` is a *default*, despite
arriving as a keyword splat. See [bugs-fixed](04-bugs-fixed.md) — this was
originally backwards.

**`<Foo className={cn(fooClasses, "extra")} />` is a subclass overriding
`#css_classes`.** When one component renders another with classes layered on
top — `ButtonGroupSeparator` and `ItemSeparator` on `Separator`,
`InputGroupInput` and `InputGroupTextarea` on `Input` and `Textarea`,
`InputGroupButton` on `Button` — inherit from the ported component and pass the
extras up:

```ruby
class Component < Shadcn::Separator::Component
  slot_name :"item-separator"

  def css_classes(extra = nil)
    super([ "my-0", extra ].compact.join(" "))
  end
end
```

Restating the parent's classes instead would work and then rot. `PaginationLink`
does the same thing one step further, borrowing `Button`'s compiled variants
rather than its instance.

### Two things a TSX says that its types do not

Both cost a wrong port before being noticed, and `parity_spec` sees neither —
it compares class tokens, not elements and not attributes.

**The type annotation is not the element.** `EmptyDescription` is typed
`React.ComponentProps<"p">` and renders a `<div>`; `ItemDescription` is typed
the same way and renders a `<p>`. Read the JSX, not the signature, and read it
per component — two families in the same batch disagreed.

**A prop with no JS default still gets a cva default.** `ButtonGroup`
destructures `orientation` without one, so `data-orientation` is *absent* until
a caller passes it, while the classes fall back to `horizontal` through cva's
`defaultVariants`. Defaulting the Ruby keyword to `:horizontal` would emit an
attribute upstream does not. The Ruby shape is a nil default for the attribute
and a resolved value for `#style_variants`.

## No npm dependency, anywhere

Three things were hand-written rather than pulled in:

- **`popper.js`** instead of `@floating-ui/dom` — it must emit the real
  `--radix-*` custom property names, because shadcn's Tailwind classes read them
  (`origin-(--radix-popover-content-transform-origin)`).
- **The `animate-in` / `fade-in-0` / `slide-in-from-*` utilities** instead of
  `tw-animate-css`, driven by Tailwind's own `--tw-duration` so `duration-200`
  keeps working.
- **The lucide icons**, inlined in `Shadcn::Icon::Component`.
- **Six utilities that are shadcn's own CSS rather than Tailwind's** —
  `shimmer`, `scroll-fade-x`, `scroll-fade-b`, `scrollbar-none`,
  `scrollbar-thin`, `scrollbar-gutter-stable`. `attachment` and the message
  scroller reach for them the way they reach for `truncate`, and Tailwind emits
  nothing for a name it does not know, so without these the components would
  ship them inert — which `parity_spec` cannot see, because it compares class
  *text* and not generated CSS.

  They are the one part of this gem with **no vendored source to diff against**:
  `vendor/shadcn/` holds TSX, examples and `themes.json` and no CSS at all, so
  they were read from the stylesheet ui.shadcn.com serves and are dated in
  `shadcn.css`. Nothing here will notice when upstream changes them. Read the
  next one rather than deriving it from a sibling: `scroll-fade-b` looked like
  `scroll-fade-x` with an axis swapped and is not — one edge rather than two, so
  one animation rather than a pair, plus `mask-composite: intersect` and a
  different timeline.

## API shape

**The `part` macro** (`app/components/shadcn/parts.rb`) replaced 53 files that
were a lookup table wrapped in module nesting. Two constraints shaped it:

- The family file is `<family>.rb`, a *sibling* of `<family>/`, so Zeitwerk can
  resolve `Shadcn::Card::Title::Component` without the family root having been
  loaded first.
- The class must be `const_set` **before** `style` is called: StyleVariants
  derives the style set's name from the class name, and an anonymous class has
  none.

Its boundary is narrower than "no behaviour": **`part` declares a slot, classes
and a tag, and no other attribute.** `ItemGroup` is a `data-slot` and two
classes — and a `role="list"`, which `part` cannot express, so it gets its own
`component.rb` (which has since grown a slot marking its items `listitem`,
`#element_attributes` staying the one line that adds `role="list"`). That is
the macro working as intended rather than a gap in it; widening it to take
arbitrary attributes would turn a lookup table back into a configuration
language.

**A host-facing registry lives in `lib/`, never in `app/`.** `Shadcn::Icon` bundles
the eleven lucide icons the ported components use; a host supplies any of the
other ~1,500 through `ShadcnViewComponent::IconRegistry.register`, and a
registration under a bundled name replaces it rather than losing to it — the
bundled eleven are defaults, and a host that is ignored has no way to find out.
Two Rails facts forced that placement, and both cost a review round to learn:

- **`app/components` is reloadable.** A hash held on a module there is discarded
  on every code reload, while `config/initializers/` runs once at boot — so a
  registration made at boot vanishes the first time the developer saves a file.
- **No autoloadable constant resolves in an initializer at all.** Railties runs
  `:setup_main_autoloader` *after* `:load_config_initializers`, so `Shadcn::Icon`
  there raises `NameError` — as would `ApplicationController`. A `lib/` constant
  required before the engine does resolve.

`Shadcn::Icon.register` remains as a delegating convenience for anywhere
autoloading works. It is simply not what the README tells a host to call.

The general rule this instance is an example of: **a library must not be able to
take down a page it has never seen.** An unknown icon name raises where
`Rails.env.local?` — development and test, where someone can fix it — and
renders nothing everywhere else, staging included. That is the trade Rails makes
with a missing translation.

**A behaviour upstream lets you ask for is a keyword here, not a decision made
for the host.** The dropdown once wrapped around at the ends of the list; that
was removed as a divergence, correctly — Radix's `loop` defaults to `false` and
shadcn never passes it. What the removal missed is that `loop` *is a prop*
(`vendor/radix/ui/menu.tsx:363-368`, documented `@defaultValue false`) and
shadcn spreads `...props` onto the content, so a React caller who wants a
cycling menu can have one. Deleting the behaviour without exposing the knob left
the port **poorer than the thing it ports**, which is a worse failure than the
divergence it fixed.

The rule that falls out: matching upstream's *default* is the job; matching its
*range* is also the job. Before removing a behaviour as non-upstream, check
whether upstream lets a caller turn it on. Such options ride on the family root
next to `side` and `align` — one Stimulus controller owns the family, and the
root is where it attaches — even where Radix declares them on Content.

## A component that is ours, not a port

The searchable select — `Select::Component.new(searchable: true)` — is the first
component here that is **not** a transcription of upstream, and it is that way
because there is nothing to transcribe.

shadcn now authors its registry as *bases* crossed with *styles*.
`grep -rl "select-input" apps/v4/registry/bases/*/ui/select.tsx` returns exactly
one file, `bases/aria/ui/select.tsx`. Neither `bases/radix` nor `bases/base` has
a searchable select. This gem ports `new-york-v4`, so the rule that upstream wins
on markup has no upstream to point at, and the component is built rather than
copied.

`new-york-v4` is what shadcn's own `apps/v4/registry/README.md:16` calls "the
legacy source registry", and that sounds worse than it measured: it and
`bases/radix` hold 61 components apiece, differing by one each way
(`questionnaire` there, `form` here), and `select.tsx`, `dropdown-menu.tsx`,
`button.tsx` and `card.tsx` are byte-identical to the copies vendored here. The
changelog says "Radix is not being deprecated. We still support it, and every
update and new component will ship for both libraries." Frozen, not abandoned —
and this component was never withheld from it, since Radix has no such component
at all. Whether to follow the new architecture is an open question in
[todo.md](../todo.md); it would not have produced this component either way.

**What was taken** from the aria variant: its shape — a `role="dialog"` popover
holding a search field and a *separate* `role="listbox"` — its `data-slot` names,
and the plain Tailwind utilities on `select-list`, `select-input-wrapper` and
`select-input`. It also composes `InputGroup`, already ported here, stamping
`data-slot="select-input"` onto an `InputGroupInput`, which is the same
inherit-and-restamp idiom `ButtonGroupSeparator` uses on `Separator`.

**What could not be taken**: `select-empty` carries only
`cn-select-empty-aria`, and the `cn-*` classes are defined in
`registry/styles/style-*.css` — six-plus themed sheets this gem does not ship.
That part's look is ours.

Three deviations, each measured rather than reasoned:

- **The search input gets an accessible name.** Upstream's has none — no
  `aria-label`, no `aria-labelledby`, no `placeholder` — and axe reports a
  *critical* `label` violation for it.
- **The empty state sits outside the listbox.** Upstream nests it inside with
  `role="option"`, an option that cannot be chosen. A non-option inside a listbox
  is the shape axe rejected outright: putting the search field inside our
  `role="listbox"` content raised `aria-required-children`, critical, "Element
  has children which are not allowed: input[aria-controls]".
- **`select-list` carries `p-1` where upstream has `p-0`**, because this port's
  padding moved off the viewport that upstream keeps.
- **The search field keeps `data-slot="input-group-control"`**, where upstream
  restamps its own as `select-input`. That name is load-bearing here and not
  there: this port's `InputGroup` raises its focus ring with
  `has-[[data-slot=input-group-control]:focus-visible]:ring-[3px]`, while the
  aria variant's `input-group.tsx` carries no `has-[[data-slot=…]]` selector at
  all and styles focus through `cn-*`. Renaming the control to match upstream
  would switch the ring off, and nothing but an eye would notice.

`parity_spec`'s `ours_alone` is the machine-readable half of this section. Parity
is one-way, so slots only this port has are invisible to it — but `todo.md` still
wants a reverse-parity check keyed on `data-slot`, and that list is what it must
not flag. An example there fails if a component stops emitting a declared slot,
so the list cannot rot into a lie.

**Ordered heterogeneous children are a polymorphic slot, not a flag.**
`ItemGroup` renders items and separators in one ordered collection through
`renders_many :items, types: { item: {…, as: :item}, separator: {…, as: :separator} }`,
which gives `with_item` and `with_separator`. A single `with_item(separator: true)`
was tried and rejected: one setter with two disjoint argument sets accepts
`with_item(separator: true, variant: :muted)` and emits `variant="muted"` as a
raw attribute on a separator, silently.

Note what forces a slot here at all: `role="list"` obliges `listitem` children,
`Item` carries no role upstream, and adding one to the component would deviate
on markup. A slot is API, which is the layer that may add what markup may not —
the same place the FormBuilder supplies the accessible name Select cannot give
itself.

**The FormBuilder** exists because porting `field.tsx` character-perfect while
shipping no `ActiveModel` bridge optimises for fidelity to React over usefulness
in Rails. `shadcn_native_select` is recommended over `shadcn_select`: it is the
one control a browser actually understands.

**I18n for every user-visible string**, with shadcn's English as the default, so
the gem works untranslated and a host app can override any key.

**An install generator**, because the Tailwind `@source` path differs between a
system gem, `bundle config set path`, and a `path:`/`git:` source — and a wrong
path fails silently, as a completely unstyled app.

## Performance

**tailwind_merge's LRU defaults to 500**, which a page of these components can
exhaust. A Rails render is an LRU's worst case: it cycles the same keys every
request, so once the working set exceeds the cache the hit rate collapses and
stays collapsed. Measured 0.6µs on a hit against ~100µs on a miss. Now
configurable via `config.shadcn_view_component.cache_size`, default 10,000.

**Static class strings are memoised** and the merger is built at boot rather than
lazily. The memo matters less for the saving than for keeping the library's own
~100 keys out of the shared LRU.

Everything else flagged as a performance worry measured as noise: the theme
registry is 146KB, the palette CSS is 4.8KB gzipped, inlined SVG compresses away.

## Tooling

**`rubocop-rails-omakase`**, because it is the style the code was already written
in: adopting it cost one offence rather than a reformat.

**`rubocop-rspec` on top, with the size cops off.** `ExampleLength` and
`MultipleExpectations` accounted for 150 of the 184 offences and are the same
thing omakase already drops for application code; a system spec is one user
journey and asserting each step of it in place is the point. What the plugin did
find worth fixing: nine constants declared inside `describe` blocks, which land
on `Object` — `previews_spec` had defined a global `COMPONENTS` duplicating
`ShadcnSource::COMPONENTS`. They are locals now. `LeakyLocalVariable` is off in
turn, because generating examples from a directory listing needs the list at
group-definition time, which is exactly what `let` cannot give.

**`Gemfile.lock` is not committed** — a library should resolve against a range,
and committing it would make the three-Ruby CI matrix run the same versions.

**CI runs `bin/setup`** rather than its steps, because the script was documented
as the entry point and nothing exercised it — which is exactly how it came to
contain a `TypeError`.
