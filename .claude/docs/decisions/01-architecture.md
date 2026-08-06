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

**`Gemfile.lock` is not committed** — a library should resolve against a range,
and committing it would make the three-Ruby CI matrix run the same versions.

**CI runs `bin/setup`** rather than its steps, because the script was documented
as the entry point and nothing exercised it — which is exactly how it came to
contain a `TypeError`.
