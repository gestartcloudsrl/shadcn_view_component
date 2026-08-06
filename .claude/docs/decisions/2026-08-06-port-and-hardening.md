# Decisions — porting shadcn/ui and hardening it (2026-08-05/06)

Why things are the way they are. `CLAUDE.md` says how to work in the repo; this
says what was chosen, what was rejected, and what turned out to be wrong.

---

## Shape of the project

**Rails engine + `test/dummy` with Lookbook**, rather than a bare `app/components`
directory or a demo app. The gallery is the only way to see whether a port
actually looks like shadcn, and it later became the fixture set for the snapshot,
preview, accessibility and system specs. *(user's call)*

**Stimulus controllers, not native HTML/CSS** for the interactive behaviour.
`<details>`/`popover`/`dialog` would have been faster but emit different DOM,
which breaks the 1:1 claim. *(user's call)*

**One ViewComponent class per React part, plus slot sugar** on the parent.
*(user's call)*

**Everything namespaced under `Shadcn::`** — a deviation from the approved plan,
which said top-level `Card::Component`. Zeitwerk cannot have `Shadcn::Card` (an
implicit namespace from `card/`) and a host app's `Card` model coexist: `Card`,
`Table`, `Field` and `Select` are all common model names. The plan's intent
(one class per part, sidecar layout) is preserved.

**`app/components/shadcn/` not `app/views/components/`.** `app/views` is
ambiguous as an autoload root; `app/components` is ViewComponent's own location
and is picked up by the engine's `app/{*,*/concerns}` glob for free.

**No npm dependency, anywhere.** Three things were hand-written rather than
pulled in:

- `popper.js` instead of `@floating-ui/dom` — it must emit the real `--radix-*`
  custom property names, because shadcn's Tailwind classes read them
  (`origin-(--radix-popover-content-transform-origin)`).
- the `animate-in` / `fade-in-0` / `slide-in-from-*` utilities instead of
  `tw-animate-css`, driven by Tailwind's own `--tw-duration` so `duration-200`
  keeps working.
- the lucide icons, inlined in `Shadcn::Icon::Component`.

**`view_component-contrib`'s `StyleVariants` as the cva port** and the
`tailwind_merge` gem as `cn()`, wired in as the style postprocessor. Both were
chosen because they are near-exact equivalents, not approximations — the
`style { base {} variants {} defaults {} compound() {} }` DSL maps onto cva
one-for-one, and `postprocess_with` is precisely where `cn()` belongs.

---

## Radix behaviours that had no direct Rails equivalent

**Context-only roots emit a `display: contents` wrapper.** `Dialog.Root`,
`Popover.Root`, `Select.Root` render no DOM in React. Stimulus needs an element.
The wrapper has no box, so layout is unaffected, and it gives shadcn's
`data-slot="dialog"` — which Radix silently drops — somewhere to live.

**Nothing is portalled to `document.body`.** Moving content out of the
controller's element unbinds the Stimulus actions on close buttons and menu
items. Discovered the hard way: the first implementation *did* portal, and the
dialog's own close button stopped working.

**Layers are promoted with the Popover API instead.** Not portalling left them
vulnerable to stacking contexts — `position: fixed` escapes overflow clipping but
never a stacking context, so a `sticky z-40` header buries a dropdown. Proved it
with a failing spec first (`spec/system/stacking_context_spec.rb`), then fixed it
with `showPopover()`, which paints above every stacking context *without* moving
the element. Feature-detected, with the old behaviour as fallback.

  The blocker I had feared — exit animations — did not exist: closing sets
  `hidden` immediately, so `data-[state=closed]:animate-out` **never plays today
  anyway**. Worth knowing before anyone tries to add exit animations.

**Indicators are rendered hidden, not omitted.** Radix mounts a checkbox tick
only while checked. Rendering it hidden keeps the markup correct without
JavaScript; the controller detaches it on connect to match Radix exactly.

**Controllers re-sync on `turbo:morph`.** Idiomorph rewrites attributes without
disconnecting, so `connect()` never runs again and the DOM silently reverts to
the server's state while the controller keeps stale ids and targets. Measured:
the JS-assigned trigger id vanished and was not reassigned. The server wins,
which is what a refresh means; `data-turbo-permanent` is the app's escape hatch.

---

## Bugs found after the fact, and what they taught

The local council (devil / simplicity / maintainability / performance) found
these; each was reproduced before being fixed.

**Attribute precedence was inverted.** What a subclass passed to `super` in
`#element_attributes` landed in the *overrides* slot, so component defaults beat
caller props — `Icon.new("x", width: "16")` rendered `width="24"`. React spreads
`{...props}` last. Fixed by swapping the merge order in the base class: one line,
no churn across the 79 files that override the method. A `element_defaults` macro
was considered and rejected as more change for the same result.

**`data: { action: … }` emitted the attribute twice.** The string spelling was
concatenated, the idiomatic Rails hash spelling was not — invalid HTML, and the
browser kept the first, so the component's own action never fired. Both spellings
are now normalised before merging.

**`crypto.randomUUID()` is secure-context only.** Over plain HTTP the controllers
threw on connect and four families were silently dead. Replaced with a counter —
these ids only need to be unique in one document.

**Escape was swallowed page-wide.** `stopPropagation()` on a document *capture*
listener meant any open layer, a tooltip included, ate the key before the host
app's own handlers. Now bubble-phase and non-stopping.

**Floating content came back in the wrong place.** `hide()` appended to the
container rather than restoring position, so after one open/close a Select's
content sat after its hidden input. Fixed with a placeholder comment node.

**The gem did not own `[hidden]`.** Closed overlays were hidden by Tailwind's
*preflight*. A host app that imports Tailwind without it would paint every
dialog, sheet, dropdown and select open on load.

**`:root` had drifted from `theme-neutral`** (`oklch(0% 0 0)` vs
`oklch(0.145 0 0)`), so the default look was not the neutral palette the docs
claimed. Now generated from the same JSON by `rake themes:build`, with a CI gate
that fails if regenerating produces a diff.

**Select, Checkbox and Switch had no accessible name.** Found by axe, and true
*even through the FormBuilder*: they are `<button>`s with an ARIA role, a
`<label for>` does not name a button, and `role="combobox"` forbids taking the
name from content. shadcn/Radix have the same gap. The FormBuilder now wires
`aria-labelledby`.

---

## Testing

**The parity spec was theatre, and two council members proved it** by mutating
code that stayed green. It compares token *sets per family*, so a class in a
comment counted, and swapping two variants' bodies passed.

Three responses, in order of value:

1. **`snapshot_spec.rb`** — golden HTML for every preview. Catches wrong part,
   wrong variant, attribute drift, extra classes. Verified against a real variant
   swap: parity passes, snapshots fail.
2. **Ripper instead of regex** for the Ruby side of parity, so a class in a
   comment can no longer count as ported.
3. **The README claim was corrected.** Overstating what a test proves is worse
   than the gap itself.

**The reverse parity check was rejected.** Classes-the-port-has-that-upstream-
doesn't was measured first: 12 of 13 families dirty with false positives (Ruby
constant names, icon names, slot names, legitimate composition). It would have
needed exactly the exception tables that were being criticised. Snapshots cover
the same ground properly.

**`stimulus_contract_spec.rb`** — the best coverage-per-line in the repo. Ruby and
JS are wired by bare strings; renaming a controller method breaks every Select in
the wild with nothing failing.

**System specs in headless Chrome** — the only place the JavaScript executes.
Previews double as fixtures. Two of the fixed bugs were re-introduced to confirm
the specs catch them.

**axe over every family**, at rest and with each layer open. Three of the first
13 "failures" were my own spec bugs (`color_contrast` should be `color-contrast`,
`button` had no `default` preview) — worth remembering that a red axe run is not
automatically a product bug.

---

## Performance

**tailwind_merge's LRU defaults to 500**, which a page of these components can
exhaust; a Rails render is an LRU's worst case, since it cycles the same keys
every request and the hit rate then collapses permanently. Measured 0.6µs on a
hit against ~100µs on a miss. Now configurable via
`config.shadcn_view_component.cache_size`, defaulting to 10,000.

**Static class strings are memoised** and the merger is built at boot rather than
lazily. The memo matters less for the saving than for keeping the library's own
~100 keys out of the shared LRU.

Everything else flagged as a performance worry measured as noise: the theme
registry is 146KB, the palette CSS is 4.8KB gzipped, inlined SVG compresses away.

---

## API shape

**The `part` macro** replaced 53 files that were a lookup table wrapped in module
nesting. Declared on the family module — which lives at `<family>.rb`, a sibling
of `<family>/`, so Zeitwerk can resolve a part without the family root being
loaded first. The class must be `const_set` *before* `style` is called, because
StyleVariants derives the style set's name from the class name.

**The FormBuilder** exists because porting `field.tsx` character-perfect while
shipping no `ActiveModel` bridge optimises for fidelity to React over usefulness
in Rails. `shadcn_native_select` is recommended over `shadcn_select`: it is the
one control a browser actually understands.

**I18n for every user-visible string**, with shadcn's English as the default, so
the gem works untranslated and a host app can override any key.

**An install generator**, because the Tailwind `@source` path differs between a
system gem, `bundle config set path`, and a `path:`/`git:` source — and a wrong
path fails silently as a completely unstyled app.

---

## Tooling

**`rubocop-rails-omakase`**, because it is the style the code was already written
in: adopting it cost one offence rather than a reformat.

**`Gemfile.lock` is not committed** — a library should resolve against a range,
and committing it would make the three-Ruby CI matrix run the same versions.

**CI runs `bin/setup`** rather than its steps, because the script was documented
as the entry point and nothing exercised it — which is exactly how it came to
contain a `TypeError`.

---

## Two traps that cost real time

**Cascade layers beat specificity.** The `:where()` reset for the Popover API's
UA styles was written unlayered, so it beat every Tailwind utility no matter how
specific and collapsed the dialog overlay to 0×0. Unlayered author styles outrank
layered ones; it belongs in `@layer base`.

**A class split across a `\` continuation generates no CSS.** Tailwind scans
source text. Two were found this way, and they would have been invisible without
the parity spec.
