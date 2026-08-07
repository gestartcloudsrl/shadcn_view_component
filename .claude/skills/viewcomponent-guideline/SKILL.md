---
name: viewcomponent-guideline
description: Use when writing or changing a ViewComponent — adding a component or part, deciding where its files go, passing HTML attributes or Tailwind classes through to the root element, choosing between slots and arguments, writing a preview, or testing one. Also for questions about view_component-contrib, StyleVariants, tailwind_merge, Lookbook previews, or why a component must not query the database.
---

# ViewComponent guidelines

A distillation of Evil Martians' three-part *ViewComponent in the Wild*
([architecture](https://evilmartians.com/chronicles/viewcomponent-in-the-wild-building-modern-rails-frontends),
[tooling](https://evilmartians.com/chronicles/viewcomponent-in-the-wild-supercharging-your-components),
[classes and attributes](https://evilmartians.com/chronicles/viewcomponent-in-the-wild-embracing-tailwindcss-classes-and-html-attributes))
and the framework's own
[best practices](https://viewcomponent.org/best_practices.html).

The worked code lives in `references/`, split so you open one file rather than
all four — [architecture](references/architecture.md),
[tooling](references/tooling.md), [styling](references/styling.md),
[official](references/official.md), indexed in
[references/README.md](references/README.md). Read the relevant one when a rule
is not obvious from its one-line statement, or when you are about to argue with
one.

**The two sources disagree twice**, and both times it matters — see
[official.md](references/official.md#where-the-two-sources-disagree). Do not
assume a rule from one is endorsed by the other.

**This repo already implements most of part three.** `ApplicationViewComponent`
is the worked example — read it before inventing anything.

## The core claim

> A view component is just a Ruby object with an associated template.

Everything below follows from taking that literally: it gets tested like an
object, composed like an object, and kept ignorant of where its data came from.

## Architecture

[Examples: architecture.md](references/architecture.md)

- **One directory per component**, sidecar style: `component.rb`,
  `component.html.erb`, `preview.rb`, and whatever else that component needs.
  The unit of organisation is the component, not the file type.
- **A component is atomic.** One responsibility. A template past ~100 lines is
  telling you to decompose, not to scroll.
- **Split general-purpose from app-specific.** Presentational components know
  nothing about your models and form the UI palette; container components use
  the palette with domain objects. If it takes an `ActiveRecord` object, it is
  app-specific.
- **Never query the database from a component.** Views render data, they do not
  fetch it. Fetch in the controller, preload, pass down. Article two shows a
  runtime linter that raises on any query issued during render.
- **Pass components, not arguments, when the child's data needs differ from the
  parent's.** That is what slots are for, and it is the cure for argument
  drilling.
- **Slots also exist for safety, not only for tidiness.** Markup passed as a
  *string argument* bypasses Rails' HTML sanitisation; markup passed as a slot
  does not. That is the framework's own reason, and it outranks taste.
- **Global state: the two sources disagree.** The articles reach for context
  (`dry-effects`) so `current_user` need not be drilled down; the framework says
  pass dependencies explicitly, because a component that reads global state
  cannot be unit tested in isolation. Pick knowingly —
  [official.md](references/official.md#global-state).
- **Extract, do not invent.** "Good frameworks are extracted, not invented":
  single use-case, then several adaptations, then extraction. Abstract at three
  similar instances, not at one.
- **No inline Ruby in templates**, and **most instance methods can be private** —
  they stay callable from the template either way.
- **Prefer a component to a partial, and to any helper that returns HTML.**

## Tooling

[Examples: tooling.md](references/tooling.md)

- **`view_component-contrib`** supplies the base classes, the sidecar preview
  support and the StyleVariants plugin. Do not rebuild them.
- **Previews are sidecar too**, via `ViewComponentContrib::Preview::Sidecarable`,
  and Lookbook renders them. A preview is documentation *and* the fixture your
  tests drive.
- **Translations live under one namespace** keyed by component path, so a
  template says `t(".title")` and nothing else has to know where it is.
- **Stimulus controllers can live beside the component** and be registered from
  the directory name, which keeps the JS next to the markup it animates.

## Styling and attributes

[Examples: styling.md](references/styling.md)

This is the part with the highest chance of being reinvented badly.

- **Declare classes, do not concatenate them.** The `style` DSL maps
  one-to-one onto `cva`: `base`, `variants`, `defaults`, `compound`.
- **Resolve conflicts with `tailwind_merge`**, wired once as the style
  postprocessor. Without it, "the caller's class wins" is a coin flip decided by
  stylesheet order.
- **Accept a bag of HTML attributes and splat it onto the root element.** That
  is React's `{...props}`, and it is what makes a component usable in situations
  its author did not anticipate.
- **Caller attributes beat component defaults.** In JSX the spread comes last;
  the Ruby equivalent has to be deliberate, because a naive `merge` gets the
  precedence backwards.

## Testing

[Examples: architecture.md](references/architecture.md#testing)

- **Test the rendered output, not the Ruby methods.** A component's methods are
  private helpers; its public interface is what it renders.
- **Do not assert exact markup.** Assert the things you would assert about any
  unit: conditional logic and computed values. `have_link`, `have_content`,
  `have_css` — not string equality against a blob of HTML.
- **Drive dynamic behaviour through previews in system tests.** The preview URL
  is a stable address for a component in isolation.

## Where this repo departs

Four deliberate divergences. The reasoning is in
[.claude/docs/decisions/01-architecture.md](../../docs/decisions/01-architecture.md).

1. **Components live in `app/components/shadcn/`, not `app/views/components`.**
   This is a Rails engine: every engine's `app/{*,*/concerns}` glob makes
   `app/components` an autoload root for free, and the `shadcn/` nesting keeps
   names like `Card`, `Table` and `Field` out of a host application's top level
   where they would collide with its models.

2. **No `dry-initializer`, no `dry-effects`, no `component` helper.** The
   articles describe an application. This is a library: every dependency it
   takes, a host takes too. Components use plain `initialize(**attributes)`, and
   there is no global state to inject because a library has no `current_user`.

3. **Attribute merging goes further than "splat the bag".** Three keys are
   *combined* rather than replaced — `class`, `data-action`, and the
   `data:`/`aria:` hashes — and `data: { action: … }` is normalised to
   `data-action` first so the two spellings cannot both reach the element. See
   [styling.md](references/styling.md#merging).

4. **A part with no behaviour gets no file.** `part` on the family module
   declares the ones that are a `data-slot` plus fixed classes; a part earns its
   own `component.rb` only once it has variants, slots, extra markup, or
   attributes computed from its arguments. See
   [architecture.md](references/architecture.md#a-part-with-no-behaviour-gets-no-file).

5. **Components inherit from each other**, which the framework's guide tells you
   to avoid. `part(..., from:)` specialises one part from another — Sheet's from
   Dialog's, `PaginationPrevious` from `PaginationLink`. Not a disagreement with
   the rule: shadcn defines them by extension, and composing instead would emit
   different markup. See
   [official.md](references/official.md#inheritance-between-components).

## Common mistakes

| Mistake | What to do instead |
|---|---|
| Merging caller attributes first, so component defaults win | Caller last. It is what `{...props}` does. |
| `class: "..."` replacing the component's classes | Concatenate, then let `tailwind_merge` decide |
| A `data-action` from the caller silently replacing the component's | Concatenate — Stimulus reads a space-separated list |
| Asserting the full rendered HTML in a spec | Assert behaviour: links, text, roles |
| A component that loads its own records | Load in the controller, pass it in |
| Building a variant system by hand with string interpolation | `style` blocks; they are `cva` |
| Adding a file for a part that is one div and two classes | `part` on the family module |
| Passing markup as a string argument | A slot — the string bypasses Rails' sanitisation |
| Logic inline in the template | An instance method; templates stay markup |

## Before finishing

- Read `ApplicationViewComponent` before adding anything to it — most of what
  you need is already there, including `render_element`, `element_attributes`
  and the class cache.
- A new component needs a preview, or it is invisible to `snapshot_spec`,
  `previews_spec` and `accessibility_spec` — in this repo those derive their
  lists from what is on disk.
- Never describe a component spec as proving more than it does. Rendered HTML is
  not behaviour, and axe is not a screen reader.
