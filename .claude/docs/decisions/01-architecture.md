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
classes — and a `role="list"`, so it gets a `component.rb` for one line of
`#element_attributes`. That is the macro working as intended rather than a gap
in it; widening it to take arbitrary attributes would turn a lookup table back
into a configuration language.

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
