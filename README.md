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
registration to `application.js`. Those three CSS lines are the reason it
exists: each one names a path into the gem, and that path differs between a
system gem, `bundle config set path`, and a `path:` or `git:` source.

**They are filesystem paths, not asset-pipeline names.** `tailwindcss-rails`
runs the Tailwind CLI with `-i` and `-o` and no load path, so the CLI resolves
a bare `@import "shadcn.css"` the way Node would — beside the file, then in
`node_modules` — and a Rails app has neither. It stops the build with
`Can't resolve 'shadcn.css'`.

Doing it by hand, with `PATH` from `bundle show shadcn_view_component`:

```css
/* app/assets/tailwind/application.css */
@import "tailwindcss";
@import "PATH/app/assets/stylesheets/shadcn.css";
@import "PATH/app/assets/stylesheets/shadcn-themes.css"; /* optional: the swappable palettes */

@source "PATH/app/components";
```

`shadcn-themes.css` has to come after `shadcn.css`: `.theme-*` and `:root` have
the same specificity, so source order is what decides.

**Prefer a relative path where you can.** An absolute one is correct on the
machine that wrote it and wrong on every other, and the CSS is built on all of
them. With `bundle config set path vendor/bundle` — what CI and most containers
do — the gem lives inside the application and the three lines can be written
relative to the entrypoint, which then holds everywhere. That is what the
generator writes when it can.

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
| Radix primitives | Stimulus controllers under `shadcn--*`, keeping the same `data-state`, `aria-*` and `--radix-*` custom properties in step with what the user does |
| `lucide-react` icons | `Shadcn::Icon::Component`, with the lucide SVGs inlined |

**The ARIA is the component's, not the controller's.** Whatever a part needs to
be what it is — its `role`, its `aria-haspopup`, a `tabindex`, the
`aria-expanded` it starts closed with — is rendered by the Ruby, so the markup
is right before any JavaScript runs and a `turbo:morph` cannot undo it. The
controllers only write what changes as the user acts — `aria-expanded` on open,
`aria-activedescendant` as the cursor moves, `aria-controls` once it knows
which element to point at. Four of them used to re-set the static half on
connect, and that was deliberately removed (commit `4e88573`): two places to
write one attribute is two places to drift.

The consequence, if you write your own markup: **`data-controller` and a
`data-shadcn--*-target` are not enough.** Hang them on a bare `<div>` and you
get a div — no role, no `aria-haspopup`, nothing for a screen reader to
announce, and no error to tell you. Render the component, or copy every
attribute it emits — `bin/console` prints them:

```ruby
render Shadcn::Select::Trigger::Component.new
# => <button data-slot="select-trigger" type="button" role="combobox"
#            aria-expanded="false" aria-autocomplete="none" …>
```

21 lucide icons are bundled — exactly the ones the ported components render,
out of lucide's ~1,500, and a spec fails if that stops being exactly true in
either direction. Their drawings are not typed into Ruby: they are the files lucide publishes,
vendored in the repository under `vendor/lucide/icons`, and `rake icons:build`
turns them into the registry the component reads. Only that registry ships in
the gem — the SVGs are a build-time source, like the upstream TSX.

**To add your own**, put SVG files in a directory and point the registry at it
from an initializer — that is where `cache_size` lives too, and the reason both
go through `ShadcnViewComponent::IconRegistry` is that nothing autoloadable
resolves there, `Shadcn::` included:

```ruby
# config/initializers/shadcn_view_component.rb
ShadcnViewComponent::IconRegistry.load_directory(Rails.root.join("app/assets/icons"))
```

The file's basename is the icon's name, and only what the `<svg>` element
contains is kept — the outer element is the component's, so lucide's own
attributes and yours never end up arguing. No asset pipeline is involved: the
files are read once, by you, when you call this. A single drawing can still be
registered by hand:

```ruby
# config/initializers/shadcn_view_component.rb
ShadcnViewComponent::IconRegistry.register("star", %(<path d="M12 2 15 9l7 .5-5 4 1 7-6-3z"/>))
```

```erb
<%= render Shadcn::Icon::Component.new("star", class: "size-4") %>
```

Registering a name the gem already bundles replaces it — `register("check", …)`
changes the tick in every checkbox, select and dropdown item — so what ships is
a set of defaults, not a fixed set.

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
input-group, input-otp

**Interactive** — accordion, collapsible, tabs, dialog, alert-dialog, sheet,
dropdown-menu (including submenus), context-menu, menubar, popover, tooltip,
hover-card, select,
scroll-area, navigation-menu, slider, sidebar, drawer, carousel

**AI chat** — message, bubble, attachment, marker, message-scroller. The first
four are markup and variants with no behaviour of their own; the scroller
follows its own live end, holds the view still when older history loads above,
and is the one component here reimplemented from a package shadcn publishes
rather than from Radix.

These are one of the two places hand-written CSS was unavoidable: `shimmer`,
`scroll-fade-x`, `scroll-fade-b`, `scrollbar-none`, `scrollbar-thin` and
`scrollbar-gutter-stable` are shadcn's own utilities rather than Tailwind's, and
are reproduced at the end of `shadcn.css`. The drawer is the other.

**Drawer** — dragged down or thrown, it closes; dragged up it gives a little and
comes back. Upstream builds this on vaul rather than Radix, and vaul is a Radix
dialog with a drag on top, so the open/close half is the dialog's here too and
only the gesture is new. Four of vaul's features are deliberately not ported —
snap points, scaling the page behind the drawer, its iOS `position: fixed`
workaround and nested drawers. Its stylesheet is the second piece of
hand-written CSS: `drawer.tsx` renders no entrance animation and no
`touch-action`, and both are load-bearing.

**Reading direction** — write `dir="rtl"` on any ancestor and the components
that navigate with arrow keys follow it. shadcn ships a `DirectionProvider` for
this; there is none here, because the browser already resolves `dir` before a
Stimulus controller runs.

**Forms** — `shadcn_form_with` and `f.shadcn_input_field`, `f.shadcn_select`,
`f.shadcn_switch` and the rest. shadcn's Form component is react-hook-form's
per-field state given five wrappers; there is no such state on a server, and
what the wrappers do with it is what Rails' `FormBuilder` already does with a
model. So that family is a FormBuilder here rather than components, built over
`field`. It emits `field-*` slots where upstream's form emits `form-*`, errors
come from `ActiveModel::Errors` after a round trip rather than as you type, and
all of an attribute's messages are shown rather than the first.

**Toaster** — notifications, stacked one behind another and fanned out under
the pointer. shadcn's is a forty-line wrapper around `sonner` and renders no
markup of its own, so this one is not a port: it keeps sonner's measurements and
its stacking, and adds the two ways a Rails app actually raises a notification —
a flash rendered with the page, and a `turbo_stream.append` onto the list.

**Calendar** — a month is a `<table role="grid">`, built in Ruby with `Date` and
`I18n` rather than by `react-day-picker`: a third of that package is locale data
and another fifth is other calendar systems, both of which a Rails app already
has. It is the one component here that renders correctly with no JavaScript at
all; the controller adds the nav, the keyboard and the selection, and takes its
month names and its idea of *today* from the server rather than from the
browser's locale and clock.

**Chart** — `chart.tsx` draws nothing: it is a container that publishes
`--color-<key>` per series, plus the contents of a tooltip and a legend that
`recharts` fills in. That frame is ported 1:1 and the shapes are drawn here, as
SVG, from the server. The pie is the first — pass a Hash of key to number, which
is what `group(:x).sum(:y)` already returns. Bars, lines and areas are not drawn
yet.

**Resizable** — panels a pointer or the arrow keys can resize. Upstream wraps
`react-resizable-panels`; here a panel is a share of a flex container, so the
layout is the browser's and the controller only moves two numbers. The handle is
a `role="separator"` with the package's own keyboard: five points an arrow, all
the way on Home and End.

**Command** — the palette. Upstream wraps `cmdk`; here the items are
server-rendered and the controller filters, *ranks* and walks them. The ranking
matters enough that `cmdk`'s own fuzzy scorer is ported rather than replaced
with a substring match: type `gp` and Group Policy comes before Groups.
`keywords:` are searched and never shown.

**Combobox** — a field that filters a list and keeps the caret. It is the one
component shadcn writes against Base UI rather than Radix, so this family alone
emits `data-open` and reads `--anchor-width`; the port publishes those names
here and nowhere else. Single selection is complete; the chips markup is there
and adding one is not wired yet.

Every component in the registry is now ported, adapted or decided against with
a reason — see [the per-component notes](.claude/docs/features/README.md).

## What is and is not verified

Worth being precise about, because "1:1" invites more trust than any test here
earns.

| Spec | Catches |
|---|---|
| `parity_spec.rb` | a class upstream emits that the port dropped or mistyped. Per *family*, not per part — swap two variants' bodies and it stays green |
| `snapshot_spec.rb` | anything that changes rendered HTML: wrong part, wrong variant, attribute drift, extra classes |
| `stimulus_contract_spec.rb` | a controller action, target or value a component names but the JavaScript does not define |
| `system/` | the behaviour, in a real browser: open/close, keyboard navigation, focus trapping, positioning, persistence, Turbo Drive and morph refreshes |
| `system/accessibility_spec.rb` | axe over every preview, **in both palettes**, at rest and with each layer open |
| `form_builder_spec.rb`, `theming_spec.rb` | the Rails form wiring, the generated palettes and the switchers |

The system specs drive headless Chrome against the gallery, so they exercise the
compiled Tailwind and the actual Stimulus controllers — `popper.js`, the layer
stack in `dismiss.js` and the focus trap in `focus.js` included.

Two things remain unverified:

- **Parity runs one way.** When upstream *removes* a class, the port keeps it
  and nothing fails. Read the TSX diff when you re-sync.
- **Accessibility is audited by axe, not by a person.** Every preview is checked
  against WCAG 2.1 AA, at rest and with its layer open, in the light palette and
  the dark one. axe catches names, roles, required parents and contrast; it does
  not replace a screen reader, and nothing here has been through one.

  The colour scheme the audit runs in is pinned, and that is not housekeeping:
  headless Chrome follows the desktop it runs on, so the suite spent this
  project's life auditing whichever palette the author was sitting in front of.
  The first run on a Linux CI runner audited the other one and found eleven real
  contrast violations.

### One thing to know if you have to meet AA

**shadcn's light palette puts `text-muted-foreground` on `bg-muted` at 4.34:1**,
where WCAG AA wants 4.5:1 — its own tokens, `muted: oklch(0.97 0 0)` against
`muted-foreground: oklch(0.556 0 0)`, and its own class string on the avatar
fallback (`avatar.tsx:49`). The same pair measures 5.85:1 in the dark palette.
`text-destructive` on `bg-destructive/10`, which the attachment's error state
and the destructive bubble use, comes to 4.00:1.

This port renders them unchanged, because upstream wins on markup and altering
them would put classes in your bundle that upstream does not emit. If you need
AA, override the token in your own CSS — one line, and it reaches every
component at once:

```css
:root { --muted-foreground: oklch(0.52 0 0); } /* measured: 5.04:1 on --muted */
```

That is the smallest step off upstream's `0.556` that clears AA — measured in
Chrome by painting both colours and computing the WCAG ratio, the same
arithmetic axe does.

## Known differences from the React DOM

Four deliberate ones, all documented at the point where they happen:

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
