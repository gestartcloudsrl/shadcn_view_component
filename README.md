# shadcn_view_component

[shadcn/ui](https://ui.shadcn.com) ported to Rails [ViewComponent](https://viewcomponent.org),
1:1 — the same part names, the same variants, the same Tailwind classes and
`data-slot` attributes. Radix UI's behaviour is reimplemented with Stimulus, so
there is no React and no npm dependency.

Two specs hold the port to upstream. `spec/parity_spec.rb` reads the TSX
vendored in `vendor/shadcn/ui` and fails if a class React emits is missing from
the Ruby; `spec/snapshot_spec.rb` diffs the rendered HTML of every preview
against a committed golden file. See
[what the specs prove](#what-is-and-is-not-verified) for the honest version.

## Installation

```ruby
# Gemfile
gem "shadcn_view_component"
```

```sh
bin/rails generate shadcn_view_component:install
```

The generator adds the imports to your Tailwind entrypoint and the Stimulus
registration to `application.js`. The `@source` line is the reason it exists:
it has to point at the gem's components inside whatever directory bundler chose,
which differs between a system gem, `bundle config set path`, and a `path:` or
`git:` source — and a wrong path fails silently, as a completely unstyled app.

Doing it by hand:

```css
/* app/assets/tailwind/application.css */
@import "tailwindcss";
@import "shadcn.css";
@import "shadcn-themes.css"; /* optional: the swappable colour palettes */

@source "<the gem's app/components — `bundle show shadcn_view_component`>";
```

`shadcn-themes.css` has to come after `shadcn.css`: `.theme-*` and `:root` have
the same specificity, so source order is what decides.

```js
// app/javascript/application.js
import { Application } from "@hotwired/stimulus"
import { registerShadcnControllers } from "shadcn"

registerShadcnControllers(Application.start())
```

The engine contributes its own importmap pins, so `shadcn` resolves with no
further configuration when the host app uses `importmap-rails`.

### Configuration

```ruby
# config/application.rb
config.shadcn_view_component.cache_size = 50_000
```

tailwind-merge keeps an LRU of merged class strings. Its own default is 500,
which a page built from these components can exhaust — and a Rails render is the
worst case for an LRU, since it cycles the same keys every request, so once the
working set exceeds the cache the hit rate collapses and stays collapsed. This
gem defaults to 10,000; raise it if you generate many distinct computed classes
(`w-[#{percent}%]` down a long table, say).

## Usage

Every React part is one component class, under `Shadcn::`:

| React | Ruby |
|---|---|
| `<Button variant="outline" size="sm">` | `Shadcn::Button::Component.new(variant: :outline, size: :sm)` |
| `<CardHeader>` | `Shadcn::Card::Header::Component` |
| `<SelectItem value="apple">` | `Shadcn::Select::Item::Component.new(value: "apple")` |

Parents also expose slots, so the common case stays short:

```erb
<%= render(Shadcn::Card::Component.new(class: "w-full max-w-sm")) do |card| %>
  <% card.with_header do |header| %>
    <% header.with_title { "Login to your account" } %>
    <% header.with_description { "Enter your email below to login." } %>
  <% end %>
  <% card.with_card_content do %>
    <%= render(Shadcn::Input::Component.new(type: "email", placeholder: "m@example.com")) %>
  <% end %>
  <% card.with_footer do %>
    <%= render(Shadcn::Button::Component.new(class: "w-full")) { "Login" } %>
  <% end %>
<% end %>
```

The explicit form is always available, and is what you want when order matters
or when parts are interleaved with labels and separators:

```erb
<%= render(Shadcn::Card::Component.new) do %>
  <%= render(Shadcn::Card::Header::Component.new) do %>…<% end %>
<% end %>
```

Slot content is rendered *before* block content, so don't mix the two inside one
parent unless you mean that ordering.

User-visible strings go through I18n under `shadcn_view_component.*`, with
shadcn's English as the default — override any key in your own locale files.

Anything you pass beyond the documented arguments lands on the element, exactly
like React's `{...props}`, and wins over what the component set itself:

```erb
<%= render(Shadcn::Button::Component.new(type: "submit", disabled: true, data: { turbo: false })) { "Save" } %>
```

`as:` is the port of shadcn's `asChild`:

```erb
<%= render(Shadcn::Button::Component.new(as: :a, href: "/login", variant: :link)) { "Log in" } %>
```

## Rails forms

`shadcn_form_with` is `form_with` with a builder that wires the `Field` family
to a model. Ids and names come from Rails; the error text, `aria-invalid`,
`aria-describedby` and `Field`'s `data-invalid` come from `ActiveModel::Errors`.

```erb
<%= shadcn_form_with model: @user do |f| %>
  <%= f.shadcn_input_field :email, label: "Email",
                                   description: "We never share it.",
                                   type: "email" %>

  <%= f.shadcn_field :plan, label: "Plan" do %>
    <%= f.shadcn_select :plan, [["Free", "free"], ["Pro", "pro"]] %>
  <% end %>

  <%= f.shadcn_submit "Create account" %>
<% end %>
```

`shadcn_field` is the wrapper — label, control, description, errors — and takes
any control in its block. `shadcn_<control>_field` is the shorthand for the
common case of exactly one.

| Control | Notes |
|---|---|
| `shadcn_input` | |
| `shadcn_textarea` | |
| `shadcn_native_select` | a real `<select>`: browser validation, autofill, native keyboard behaviour |
| `shadcn_select` | the styled listbox; submits through a hidden input, so `required` will **not** stop the form |
| `shadcn_checkbox`, `shadcn_switch` | boolean attributes |
| `shadcn_radio_group` | each option labelled and wired by id |
| `shadcn_submit` | |

Prefer `shadcn_native_select` unless you specifically want the styled listbox —
it is the one control here that a browser understands.

`form_with(..., builder: ShadcnViewComponent::FormBuilder)` does the same thing
if you would rather be explicit, and works with `fields_for` too.

### A select you can filter

`searchable: true` puts a search field at the top of the open panel and narrows
the options as you type — case-insensitively, on a substring, so `err` finds
*Blueberry*. It works on the component and through the form builder:

```erb
<%= render(Shadcn::Select::Component.new(name: "country", searchable: true)) do |s| %>
  <% s.with_trigger { |t| t.with_value(placeholder: "Select a country") } %>
  <% s.with_select_content do %>
    <%= render(Shadcn::Select::Item::Component.new(value: "it")) { "Italy" } %>
  <% end %>
<% end %>

<%= f.shadcn_select :country, choices, searchable: true %>
```

Two things to know before reaching for it.

**The filter is client-side**, over the options already on the page. For a list
long enough that you would not render it all, listen for `input` on
`[data-slot=select-input-wrapper] input` and swap the options through a Turbo
Frame — the gem takes no position on that and ships no server mode.

**This one is not a port.** Every other component here reproduces a shadcn
component; no Radix-based shadcn select has a filter, so this one takes its
shape from the React Aria variant and is otherwise the gem's own. What that
means for you: its look is not guaranteed to match a future upstream, and
[`.claude/docs/decisions/01-architecture.md`](.claude/docs/decisions/01-architecture.md)
records where it deliberately differs.

## How the mapping works

| shadcn (React) | this gem |
|---|---|
| `cva(base, { variants, defaultVariants })` | `ViewComponentContrib::StyleVariants` — the `style { base {} variants {} defaults {} }` DSL |
| `cn(...)` (clsx + tailwind-merge) | the `tailwind_merge` gem, wired in as the style postprocessor, so caller classes win conflicts |
| `data-slot="card-header"` | `slot_name :"card-header"` |
| `{...props}` | `**attributes`, splatted through Rails' tag builder |
| `asChild` | `as:` |
| Radix primitives | Stimulus controllers under `shadcn--*` emitting the same `data-state`, `role`, `aria-*` and `--radix-*` custom properties |
| `lucide-react` icons | `Shadcn::Icon::Component`, with the lucide SVGs inlined |

Eleven lucide icons are bundled — the ones the ported components themselves
use, out of lucide's ~1,500. Register another through
`ShadcnViewComponent::IconRegistry` — the same place `cache_size` above
lives — so it works from `config/initializers/`, where nothing autoloadable
resolves yet, `Shadcn::` included:

```ruby
# config/initializers/shadcn_view_component.rb
ShadcnViewComponent::IconRegistry.register("star", %(<path d="M12 2 15 9l7 .5-5 4 1 7-6-3z"/>))
```

```erb
<%= render Shadcn::Icon::Component.new("star", class: "size-4") %>
```

Registering a name the gem already bundles replaces it — `register("check", …)`
changes the tick in every checkbox, select and dropdown item — so the eleven are
defaults, not a fixed set.

`Shadcn::Icon.register` / `.registered` delegate to the same registry and read
more naturally from a view or another component — anywhere autoloading has
already run, which is everywhere except an initializer.

An unknown name raises where `Rails.env.local?` is true — development and
test, where a typo can still be fixed — and renders nothing everywhere else,
staging included: the gem cannot know every icon a host will ever pass it,
and a missing one is not worth a 500.

Components live in sidecar directories following the
[Evil Martians layout](https://evilmartians.com/chronicles/viewcomponent-in-the-wild-building-modern-rails-frontends):
`app/components/shadcn/<family>/[<part>/]{component.rb,preview.rb,previews/*.html.erb}`.

Everything is namespaced under `Shadcn::` rather than sitting at the top level,
because names like `Card`, `Table`, `Field` and `Select` would otherwise collide
with a host application's own models.

## Theming

Theming works exactly as shadcn documents it: semantic CSS variables under
`:root` and `.dark`, mapped into Tailwind utilities by `@theme inline`. Override
`--primary` and every `bg-primary` in the app follows. The full token table is
in [the shadcn theming docs](https://ui.shadcn.com/docs/theming); this gem ships
the same tokens and the same `--radius` scale.

On top of that there are two independent switchable axes, ported from what runs
on ui.shadcn.com:

| Axis | Values | Applied as |
|---|---|---|
| mode | `light`, `dark`, `system` | `.dark` on `<html>` |
| theme | one of 24 palettes | `theme-<name>` on `<body>` |

### Wiring it up

```erb
<%# app/views/layouts/application.html.erb %>
<html>
  <head>
    <%= shadcn_theme_script_tag %>
  </head>
  <body class="<%= shadcn_theme_class %>">
    <%= render(Shadcn::ModeToggle::Component.new) %>
    <%= render(Shadcn::ThemeSelector::Component.new(value: shadcn_theme_name)) %>
```

`shadcn_theme_script_tag` is the piece that matters: it runs before the first
paint, reads the stored preference and sets `.dark` and `data-shadcn-theme` on
`<html>` — which is why there is no flash of the wrong palette. It is the
equivalent of what `next-themes` injects.

The preference is stored in `localStorage` (as upstream) and mirrored into a
cookie, so `shadcn_theme_class` and `shadcn_mode` can render the right thing
server-side on the very first byte.

### The switchers

| Component | Upstream | What it is |
|---|---|---|
| `Shadcn::ModeToggle::Component` | `examples/mode-toggle.tsx` | The documented dropdown: Light / Dark / System |
| `Shadcn::ModeSwitcher::Component` | `components/mode-switcher.tsx` | The single button in shadcn's own header, straight light↔dark |
| `Shadcn::ThemeSelector::Component` | `components/theme-selector.tsx` | A select over the palettes |

Driving it yourself is a matter of one Stimulus action inside a
`shadcn--theme` controller:

```erb
<div data-controller="shadcn--theme">
  <button data-action="shadcn--theme#toggle">Flip the mode</button>
  <button data-mode="dark" data-action="click->shadcn--theme#setMode">Dark</button>
  <button data-value="zinc" data-action="click->shadcn--theme#setTheme">Zinc</button>
</div>
```

Or from your own JavaScript:

```js
import { setMode, setTheme, resolvedMode } from "shadcn/theme"
```

### The palettes

Seven base greys — neutral, stone, zinc, mauve, olive, mist, taupe — and
seventeen accents: amber, blue, cyan, emerald, fuchsia, green, indigo, lime,
orange, pink, purple, red, rose, sky, teal, violet, yellow.

The base greys carry a complete token set. The accents are overlays: they
redefine `--primary` and the chart colours and let the rest fall through to
`:root`, which is why dropping one onto `<body>` recolours an app without
restating the neutrals.

Palettes also scope, so you can theme one region of a page:

```erb
<div class="theme-blue">…</div>
```

`ShadcnViewComponent::Themes` is the registry behind all of this
(`ALL`, `BASE_COLORS`, `ACCENTS`, `find`). Both the registry and
`shadcn-themes.css` are generated from `vendor/shadcn/themes.json` — run
`rake themes:build` after refreshing it.

### A few rules resist an ordinary `!important`

`[data-slot][hidden]`, `[data-slot][data-exiting]` and the two
`animate-accordion-*` reduced-motion overrides in `shadcn.css` are
`!important` inside a cascade layer, which beats an `!important` of your own
at any specificity. An inline `style` attribute gets past it, and so does a
`@layer` declared earlier than this stylesheet in your document.

## Components

**Theming** — mode-toggle, mode-switcher, theme-selector

**Presentational** — button, badge, card, alert, avatar, separator, skeleton,
spinner, kbd, aspect-ratio, progress, table, breadcrumb, pagination, label,
input, textarea, native-select, field, empty, item, button-group

**Form controls** — checkbox, radio-group, switch, toggle, toggle-group,
input-group

**Interactive** — accordion, collapsible, tabs, dialog, alert-dialog, sheet,
dropdown-menu (including submenus), popover, tooltip, select, sidebar

Not ported: chart, sonner, calendar, carousel, resizable, input-otp, command,
combobox, menubar, navigation-menu, context-menu, hover-card, scroll-area,
slider, form, drawer, and the AI chat components.

## What is and is not verified

Worth being precise about, because "1:1" invites more trust than any test here
earns.

| Spec | Catches |
|---|---|
| `parity_spec.rb` | a class upstream emits that the port dropped or mistyped. Per *family*, not per part — swap two variants' bodies and it stays green |
| `snapshot_spec.rb` | anything that changes rendered HTML: wrong part, wrong variant, attribute drift, extra classes |
| `stimulus_contract_spec.rb` | a controller action, target or value a component names but the JavaScript does not define |
| `system/` | the behaviour, in a real browser: open/close, keyboard navigation, focus trapping, positioning, persistence, Turbo Drive and morph refreshes |
| `system/accessibility_spec.rb` | axe over every family, at rest and with each layer open, plus contrast in dark mode |
| `form_builder_spec.rb`, `theming_spec.rb` | the Rails form wiring, the generated palettes and the switchers |

The system specs drive headless Chrome against the gallery, so they exercise the
compiled Tailwind and the actual Stimulus controllers — `popper.js`, the layer
stack in `dismiss.js` and the focus trap in `focus.js` included.

Two things remain unverified:

- **Parity runs one way.** When upstream *removes* a class, the port keeps it
  and nothing fails. Read the TSX diff when you re-sync.
- **Accessibility is audited by axe, not by a person.** Every family is checked
  against WCAG 2.1 AA, at rest and with its layer open, plus contrast in dark
  mode. axe catches names, roles, required parents and contrast; it does not
  replace a screen reader, and nothing here has been through one.

## Known differences from the React DOM

Three deliberate ones, all documented at the point where they happen:

1. **Context-only roots render an element.** Radix's `Dialog.Root`,
   `Popover.Root`, `Select.Root` and friends render no DOM at all. Stimulus
   needs something to attach to, so those roots emit a `display: contents`
   wrapper. It has no box and no effect on layout, and it gives shadcn's
   `data-slot="dialog"` — which Radix silently drops — somewhere to live.

2. **Nothing is portalled to `document.body`.** Radix moves overlays and
   floating content onto the body. Here they stay inside the component, wrapped
   in the same `data-slot="*-portal"` / `data-radix-popper-content-wrapper`
   elements, because moving them out of the controller's element would unbind
   the Stimulus actions on the close buttons and menu items.

   Staying put means a stacking context above the component could bury it —
   `position: fixed` escapes overflow clipping but never a stacking context, and
   a `sticky z-40` header or an `isolate` card is ordinary markup. The Popover
   API solves exactly that: opening calls `showPopover()`, which paints the
   layer above every stacking context *without* moving it in the DOM. Browsers
   without the API fall back to plain `position: fixed`, which is correct except
   under such an ancestor. `spec/system/stacking_context_spec.rb` holds this.

   One case does remain: an ancestor with `transform`, `filter` or `contain`
   becomes the containing block for fixed descendants, which affects where the
   layer is positioned rather than what paints over it.

3. **A morph refresh resets a component to the server's state.** Turbo's morph
   rewrites attributes in place without disconnecting the Stimulus controllers,
   so `connect()` never runs again. The controllers re-sync on `turbo:morph`, so
   the DOM and the controller always agree — but what a component was showing is
   whatever the server just rendered. If a component's open state should survive
   a refresh, mark it `data-turbo-permanent`; that is your call, not the
   library's.

4. **Indicators are hidden, not unmounted, before JavaScript runs.** Radix
   mounts a checkbox tick or a select checkmark only while checked. The server
   renders them with `hidden` so the markup is right without JavaScript, and the
   controller detaches them on connect to match Radix exactly.

## Development

```sh
bin/setup                  # bundle install + build Tailwind
bundle exec rake           # the whole suite
bin/console                # IRB with the dummy app, to render components
cd test/dummy && bin/rails s
```

Then open <http://localhost:3000/lookbook> for the component gallery.
See [CONTRIBUTING.md](CONTRIBUTING.md) for adding a component and re-syncing
with upstream.

## License

MIT. The vendored shadcn/ui sources under `vendor/shadcn` are MIT too; see
`vendor/shadcn/LICENSE.md`.
