# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Rails engine gem that ports [shadcn/ui](https://ui.shadcn.com) to ViewComponent
**1:1**: same part names, variants, Tailwind classes and `data-slot` attributes.
Radix UI's behaviour is reimplemented in Stimulus — no React, no npm dependency
at runtime.

Two constraints decide everything here, and between them they settle most
questions without having to ask.

**It is 1:1 with upstream.** When upstream and idiomatic Rails disagree, upstream
wins on *markup* and Rails wins on *API*.

**It is a library to be published, not an application.** The code runs inside
someone else's Rails app, against their models, their Tailwind config, their
Turbo, their CSP — none of which can be inspected from here. So when a choice is
borderline, take the one that survives a host you cannot see. That is what
already decided: `Shadcn::` namespacing (a host's `Card` model would collide),
caller attributes beating component defaults, the gem owning
`[data-slot][hidden]` rather than trusting Tailwind preflight to be loaded, a
cache sized for a real page rather than the library's own defaults, and
`Gemfile.lock` staying uncommitted so the matrix resolves against a range.
Ambiguity resolves toward "has to hold up in an app I will never see", not
toward "good enough here".

**Before deciding *how* to build something, open upstream's own example and read
what it renders — its shape, not its looks.** Not the vendored copy — the live component on
[ui.shadcn.com](https://ui.shadcn.com), in the right variant tab. The vendored
sources say what was true when they were copied and answer "what does this
version do"; they never answer "what does upstream do today", and neither
question is "what shape did upstream choose". Inspect the rendered DOM: roles,
`data-slot` names, which element owns which ARIA attribute.

The searchable select is the worked example. Two candidate shapes were designed
here and argued between, and upstream's answer was neither: its popover is
`role="dialog"` holding a *separate* listbox, which dissolves the question
instead of answering it. Both candidates had been derived, correctly, from the
parts already measured — and the part never looked at was the one that decided
it. The dropdown's wrap-around went the same way: three vendored files agreed
and the conclusion was still wrong, because the docs now show a different
variant first.

Reading the source is how a claim gets *checked*. Looking at the example is how
a decision gets *made*. What the example does **not** settle is appearance: the
docs now serve the Base UI registry, whose Button is a different component from
the `new-york-v4` one ported here, so a class string is checked against
`vendor/shadcn/ui/` and never against a screenshot.

**Read [`.claude/docs/`](.claude/docs/README.md) before changing anything
structural** — it holds why the port is shaped the way it is, and which
alternatives were already measured and rejected.

## Commands

```sh
bin/setup                                     # bundle install + build Tailwind
bundle exec rake                              # everything (rspec)
bin/rubocop                                   # Rails omakase style; -a to autocorrect
bin/console                                   # IRB + dummy app; `render`, `slots`, `upstream`, `reload!`

bundle exec rspec spec/system                 # browser specs only (needs Chrome)
bundle exec rspec spec/system/dialog_spec.rb
bundle exec rspec spec/parity_spec.rb -e "card.tsx"

SNAPSHOTS=overwrite bundle exec rspec spec/snapshot_spec.rb   # regenerate golden HTML

bundle exec rake themes:build                 # regenerate palettes from vendor/shadcn/themes.json

cd test/dummy && bin/rails s                  # gallery at http://localhost:3000/lookbook
cd test/dummy && bin/rails tailwindcss:watch  # keep CSS fresh while editing classes
```

`tailwindcss:build` / `tailwindcss:watch` only work from `test/dummy`, not the
repo root. Without a build the gallery renders **unstyled rather than erroring**,
because the CSS is a compiled bundle.

## Where things are

```
app/components/shadcn/
  application_view_component.rb  # the whole React→Ruby mapping
  parts.rb                       # the `part` macro
  <family>.rb                    # `part` declarations for the trivial sub-components
  <family>/component.rb          # the family root
  <family>/<part>/component.rb   # parts that have behaviour
  <family>/preview.rb + previews/*.html.erb

app/javascript/shadcn/           # 15 controllers + popper, dismiss, focus,
                                 # floating, top_layer, theme, id
lib/shadcn_view_component/       # engine, form_builder, generated themes registry
lib/tasks/themes.rake            # the theme generator
vendor/shadcn/                   # upstream TSX + themes.json, the parity reference
vendor/radix/                    # the Radix primitives shadcn wraps — what the
                                 # controllers are answerable to on behaviour
vendor/shadcn-react/             # @shadcn/react, the primitive shadcn publishes
                                 # itself — same role, for the message scroller
```

A part that is only an element with a `data-slot` and fixed classes is declared
with `part` on the family module. It gets its own `component.rb` as soon as it
has variants, slots, extra markup, or attributes computed from its arguments.

The family file `<family>.rb` is a *sibling* of `<family>/`, not inside it —
see [architecture](.claude/docs/decisions/01-architecture.md#api-shape).

## Traps

These bite while editing, so they are here rather than in the docs.

- **Never split a class string across a `\` line continuation.** Tailwind scans
  source text, so half a token generates no CSS. `parity_spec` catches it.
- **Generated files are not hand-edited**: `lib/shadcn_view_component/themes.rb`,
  `app/assets/stylesheets/shadcn-themes.css`, and the `shadcn-tokens` block
  inside `shadcn.css`. Edit `vendor/shadcn/themes.json`, run `rake themes:build`.
  CI fails if regenerating produces a diff.
- **Attribute precedence is `data-slot` < component defaults < caller.** What a
  subclass passes to `super` in `#element_attributes` is a *default*, despite
  arriving as a keyword splat. `class` and `data-action` concatenate rather than
  replace.
- **Slot content renders before block content.** Mixing the two in one parent
  reorders things — see the select and dropdown previews for why they render
  items in the block.
- **Select, Checkbox and Switch are `<button>`s with an ARIA role**, so they need
  a name pointed at them — the FormBuilder wires `aria-labelledby`, a bare
  component has nothing; `ThemeSelector` names its trigger the same way. (`<label
  for>` *does* name a button, but `role="combobox"` is the case that cannot take
  its name from content, so the gem does not rely on it.)
- **The gallery layout carries its own ModeToggle and ThemeSelector**, so in
  system specs a preview's dropdown or select is not the only one on the page —
  scope lookups (`all("[data-slot=select]").last`).

- **A comment written one scope wider than the line you checked.** Twelve
  findings across one branch were all this shape: "Radix" written after reading
  `menu.tsx`, "byte-identical" after comparing two function bodies, "at boot"
  after trying one initializer. Each was true of the case examined and false of
  the case named — and several were introduced by the round fixing the previous
  one. The check that catches it is not *is this true?* but **which file did I
  open, and does the sentence stay inside it?** Where the answer is "one file of
  several", name the file. Where a claim cannot be checked from what is vendored
  here, say that instead of asserting it.

## Which spec to reach for

| | |
|---|---|
| `parity_spec.rb` | did a class upstream emits get dropped or mistyped |
| `snapshot_spec.rb` | did the rendered HTML change at all |
| `stimulus_contract_spec.rb` | does every `shadcn--x#action`, target and value exist in the JS |
| `reduced_motion_spec.rb` | does the *compiled* bundle still collapse each animation under `prefers-reduced-motion` |
| `system/` | does it behave, in headless Chrome |
| `system/accessibility_spec.rb` | axe, every family, at rest and with each layer open |

Each of these has a real blind spot — parity is family-granular and one-way, axe
is not a screen reader. [testing](.claude/docs/decisions/03-testing.md) says
exactly what each does and does not prove; do not quote stronger guarantees than
that file supports.

Previews are both documentation and fixtures: adding one to a new component is
what gets it covered by the snapshot, preview and accessibility specs.

## Background

- [Architecture](.claude/docs/decisions/01-architecture.md) — project shape, the
  cva/`cn` mapping, `Shadcn::` namespacing, the no-npm rule, `part`, FormBuilder,
  performance, tooling
- [JavaScript](.claude/docs/decisions/02-javascript.md) — why nothing is
  portalled, the Popover API top layer, `turbo:morph`, and the cascade-layer trap
- [Testing](.claude/docs/decisions/03-testing.md) — including the rejected
  reverse-parity check, the system-spec pitfalls, what each `vendor/` reference
  is and is not evidence for, and why a control measurement comes first
- [Bugs fixed](.claude/docs/decisions/04-bugs-fixed.md) — things not to
  reintroduce
- [Features](.claude/docs/features/README.md) — per component, whether it is 1:1
  with shadcn or adapted, extended or ours, and why. Written to be lifted into
  the public README rather than summarised again.
- [TODO](.claude/docs/todo.md) — open work, the 17 unported components grouped
  by what actually blocks them, and what is deliberately not being done
