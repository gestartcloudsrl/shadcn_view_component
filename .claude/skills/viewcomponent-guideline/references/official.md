# The official best practices

From [viewcomponent.org/best_practices.html](https://viewcomponent.org/best_practices.html).

Read this file for the seven rules the Evil Martians articles do not cover, and
for the two places where the two sources genuinely disagree. Everything marked
**Also in the articles** is here only so you know it is not a fourth opinion.

## Where the two sources disagree

### Global state

**The official guide:** *Avoid global state.* Pass dependencies explicitly
rather than reaching for request parameters or the current URL. A component that
depends on global state cannot be unit tested in isolation, and thorough unit
testing is what proves the decoupling.

**The articles:** use context — `dry-effects` — so `current_user` does not have
to be threaded through five layers. See [architecture.md](architecture.md#context-for-genuinely-global-state).

This is a real disagreement, not a difference of emphasis. Both are defensible:
the official rule optimises for testability in isolation, the articles for not
drilling one argument through an entire component tree.

**This repo sides with the official guide**, though it never had to choose: a
library has no `current_user` and no request. Nothing in `Shadcn::` reads
anything it was not passed. If you are building an *application* on these
components, that is where the choice becomes live.

### Inheritance between components

**The official guide:** *Avoid inheritance.* "Having one ViewComponent inherit
from another leads to confusion." Wrap with composition instead.

**This repo does the opposite, deliberately.** The `part` macro takes a `from:`
so one part can specialise another:

```ruby
part(name, slot:, classes: nil, tag: nil, from: ApplicationViewComponent)
```

Sheet's parts derive from Dialog's; `PaginationPrevious` derives from
`PaginationLink` and inherits its `slot_name`. The reason is the port's own
constraint rather than a view on the rule: **shadcn itself defines these by
extension** — `sheet.tsx` reuses dialog's parts — and the port is 1:1. Composing
instead would produce different markup, which is the one thing this repo will
not trade.

Note the rule is about *component-to-component* inheritance. Every component
inheriting a shared `ApplicationViewComponent` base is normal and not what the
guide warns about.

## Rules the articles do not cover

**Prefer slots over passing markup as an argument — for security.** The articles
recommend slots too, but for a different reason (a child whose data needs differ
from its parent). The official guide adds the one that settles it: passing
markup as an argument "bypasses the HTML sanitization provided by Rails,
creating the potential for security issues." Slots go through Rails' output
safety; a string argument interpolated into a template does not.

**Avoid inline Ruby in templates.** Move the logic to an instance method. The
template should read as markup.

**Most instance methods can be private.** They remain callable from the
template, so `private` costs nothing and keeps the public surface to what
callers actually use.

**Use the `-Component` suffix.** It makes it clear the class is a component and
follows Rails convention. *This repo satisfies this by directory convention
rather than by class name*: every component class is literally named `Component`
inside a namespace that names it — `Shadcn::Button::Component` — which is the
`view_component-contrib` layout, and reads the same way at the call site.

**Prefer ViewComponents over partials, and over helpers that return HTML.** Both
are the same rule: if it generates markup, it should be a testable object rather
than a file resolved by string lookup or a method returning a `String`.

**Extract, don't invent.** "Good frameworks are extracted, not invented." The
sequence is single use-case → several adaptations → extraction. Abstracting
after three or more similar instances, not before.

*This repo is the exception that proves it*: the components were not extracted
from anything, they were ported from a design system that had already done the
extracting. Inventing an abstraction is only safe when someone else has already
paid for the mistake.

**Reduce permutations, avoid one-offs.** "Every new component introduced adds to
application maintenance burden." Consolidate similar patterns rather than
growing a family of near-duplicates.

**When a whole route should be a component.** Rarely worth it for a plain `show`
view; worth it when the view has many permutations driven by state, because then
unit testing buys something.

## Also in the articles

Listed so you can recognise agreement rather than mistake it for a new rule.

| Official guide | Articles |
|---|---|
| Two types: general-purpose and application-specific | [architecture.md](architecture.md#atomicity-and-the-two-kinds-of-component) |
| Test against rendered content, not instance methods | [architecture.md](architecture.md#testing) |
| Single responsibility per component | same, stated as atomicity |
| Prefer slots to argument drilling | [architecture.md](architecture.md#pass-components-not-arguments) — different reason, same conclusion |

## The framing worth keeping

> ViewComponent is to UI what ActiveRecord is to SQL.

And the observation that explains most of the pain of a first conversion:
**ViewComponent exposes existing complexity.** Turning a template into a
component surfaces the dependencies it always had. That is the point, not a
regression.
