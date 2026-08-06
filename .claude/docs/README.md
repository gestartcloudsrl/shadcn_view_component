# Working notes

`CLAUDE.md` at the repo root says *how* to work here. These say *why*, and what
is left.

| | |
|---|---|
| [decisions/01-architecture.md](decisions/01-architecture.md) | project shape, the cva/`cn` mapping, `Shadcn::` namespacing, no-npm rule, the `part` macro, FormBuilder, performance, tooling |
| [decisions/02-javascript.md](decisions/02-javascript.md) | how Radix was reimplemented: `display: contents` roots, why nothing is portalled, the Popover API top layer, `turbo:morph` |
| [decisions/03-testing.md](decisions/03-testing.md) | what each spec proves and does **not**, the rejected reverse-parity check, system-spec pitfalls |
| [decisions/04-bugs-fixed.md](decisions/04-bugs-fixed.md) | the council's findings and their fixes — a list of things not to reintroduce |
| [decisions/05-exit-animations.md](decisions/05-exit-animations.md) | why every `animate-out` class is inert, and the `getAnimations()` design that fixes it — **not implemented yet** |
| [todo.md](todo.md) | open work, ordered by what blocks a release, plus what is deliberately not being done |

Written during the initial port and hardening pass, 2026-08-05/06. Anything
measured is marked as measured; anything assumed says so.
