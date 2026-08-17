# Contributing

```sh
bin/setup                                  # bundle install + build Tailwind
bundle exec rake                           # the whole suite
bin/rubocop                                # Ruby style, `-a` to autocorrect
bin/eslint                                 # the controllers, `--fix` likewise
cd test/dummy && bin/rails s               # the gallery at /lookbook
```

Style is [Rails omakase](https://github.com/rails/rubocop-rails-omakase), which
is what the codebase was already written in. Nothing polices line length or
method size — the point is to keep reviews about the code.

`bin/eslint` is there for one class of bug rather than for style: a reference
to something that does not exist. `stimulus_contract_spec` checks that every
action, target and value a *component* names exists in the JavaScript, and says
nothing about whether the JavaScript itself calls a function nobody defined.
It found one on the first run. Node is a development dependency and only that —
the gem ships no npm package and needs none at runtime.

## Adding a component

Components live in sidecar directories, one class per React part:

```
app/components/shadcn/
  <family>.rb                  # the family's declarative parts
  <family>/
    component.rb               # Shadcn::Family::Component
    <part>/component.rb        # parts that have behaviour
    preview.rb                 # Shadcn::Family::Preview
    previews/default.html.erb
```

Most of shadcn's sub-components are just an element with a `data-slot` and some
classes. Those are declared on the family module rather than given a file each:

```ruby
# app/components/shadcn/card.rb
module Shadcn
  module Card
    extend Parts

    part :title, slot: "card-title", classes: "leading-none font-semibold"
    part :footer, slot: "card-footer", classes: "flex items-center px-6 [.border-t]:pt-6"
  end
end
```

`part` takes `tag:` when the element is not a `<div>`, and `from:` to specialise
another part (Sheet's overlay is Dialog's with a different slot). It defines the
same `Shadcn::Card::Title::Component` a file would, so nothing else changes.

A part gets its own `component.rb` as soon as it has *behaviour*: variants,
slots, extra markup, or attributes computed from its arguments.

1. Copy the upstream TSX into `vendor/shadcn/ui/` and add it to `PORTS` in
   `spec/parity_spec.rb`.
2. Write the class or the `part` declaration. `slot_name` is the `data-slot`
   shadcn stamps; `default_tag` is the element the TSX renders; `style do … end`
   is the cva block. Keep every class string **literal and unsplit** — Tailwind
   scans source text, so a class broken across a `\` continuation generates no
   CSS. `parity_spec` will tell you if one goes missing.
3. Anything a subclass passes up through `super` in `#element_attributes` is a
   *default*: the caller's attributes are merged on top, matching React's
   `{...props}`.
4. Add a preview, then `SNAPSHOTS=overwrite bundle exec rspec` and read the
   diff before committing it.

User-visible strings go through `shadcn_t("…")` and `config/locales/en.yml`.

## What the specs actually prove

| Spec | Guards against |
|---|---|
| `parity_spec.rb` | a class upstream emits that the port dropped or mistyped — per family, not per part |
| `snapshot_spec.rb` | anything that changes the rendered HTML: wrong part, wrong variant, attribute drift |
| `stimulus_contract_spec.rb` | a controller action, target or value a component names but JavaScript does not define |
| `system/` | the behaviour in a real browser |
| `form_builder_spec.rb`, `theming_spec.rb` | the Rails form wiring, the palettes and the switchers |

### System specs

They drive headless Chrome against the gallery, so a preview is both the
documentation and the fixture — add one for a new component and it is covered.

```sh
bundle exec rspec spec/system                  # the browser specs alone
bundle exec rspec spec/system/dialog_spec.rb
```

They need Chrome installed; Selenium Manager fetches the matching driver.
Screenshots of failures land in `test/dummy/tmp/capybara`.

A few things worth knowing before adding one:

- The gallery layout carries a ModeToggle and a ThemeSelector, so a preview's
  own dropdown or select is **not** the only one on the page. Scope lookups —
  `all("[data-slot=select]").last` is the preview's.
- Closed content is `hidden`, so `have_no_css` means closed and `visible: :all`
  is how you assert on it anyway.
- `click_outside` clicks a viewport corner. Clicking an overlay element does not
  work: Selenium aims at its centre, which is where the dialog sits.
- `press(:escape)` sends keys to the page rather than to an element.

## Re-syncing with upstream

```sh
git clone --depth 1 https://github.com/shadcn-ui/ui /tmp/shadcn-ui
cp /tmp/shadcn-ui/apps/v4/registry/new-york-v4/ui/<name>.tsx vendor/shadcn/ui/
(cd /tmp/shadcn-ui && git rev-parse HEAD) > vendor/shadcn/REVISION
bundle exec rspec spec/parity_spec.rb
```

For the palettes, refresh `vendor/shadcn/themes.json` from
`apps/v4/registry/themes.ts` (strip the `export const THEMES =` prefix and the
`as const satisfies …` suffix) and run `bundle exec rake themes:build`.

Note that `parity_spec` only runs one way: when upstream *removes* a class, the
port keeps it and nothing fails. Read the TSX diff when you re-sync.

## Labelling the button-based controls

Select, Checkbox and Switch render a `<button>` carrying an ARIA role. A
`<label for>` does **not** name a button, and `role="combobox"` goes further and
forbids taking the name from the element's own content — so these three reach the
browser unnamed unless you say otherwise:

```erb
<%= render(Shadcn::Switch::Component.new("aria-labelledby": "news-label")) %>
<%= render(Shadcn::Label::Component.new(id: "news-label")) { "Newsletter" } %>
```

`shadcn_field` does this for you. `spec/system/accessibility_spec.rb` fails if a
preview forgets it, which is how the gallery stays an example worth copying.
