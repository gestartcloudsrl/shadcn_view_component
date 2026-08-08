# Working notes

`CLAUDE.md` at the repo root says *how* to work here. `decisions/` says *why*,
`todo.md` says what is left, and `plans/` holds the plan a branch was worked out
from before any of it was written.

| | |
|---|---|
| [decisions/01-architecture.md](decisions/01-architecture.md) | project shape, the cva/`cn` mapping, `Shadcn::` namespacing, no-npm rule, the `part` macro, FormBuilder, performance, tooling |
| [decisions/02-javascript.md](decisions/02-javascript.md) | how Radix was reimplemented: `display: contents` roots, why nothing is portalled, the Popover API top layer, `turbo:morph` |
| [decisions/03-testing.md](decisions/03-testing.md) | what each spec proves and does **not**, the rejected reverse-parity check, system-spec pitfalls, what the two `vendor/` references are worth and why a control measurement is not optional |
| [decisions/04-bugs-fixed.md](decisions/04-bugs-fixed.md) | the council's findings and their fixes — a list of things not to reintroduce |
| [todo.md](todo.md) | open work, ordered by what blocks a release, plus what is deliberately not being done |
| [plans/2026-08-06-exit-animations.md](plans/2026-08-06-exit-animations.md) | the plan the exit-animation work was executed from: the three closing paths, what each way of interrupting a half-finished close does, the reduced-motion collapse |
| [plans/2026-08-07-plain-ports-group-a.md](plans/2026-08-07-plain-ports-group-a.md) | vendoring the 27 unported sources, and porting the four that are markup only |
| [plans/2026-08-07-smaller-things.md](plans/2026-08-07-smaller-things.md) | closing eleven of the twelve entries under *Smaller things* |
| [plans/2026-08-08-searchable-select.md](plans/2026-08-08-searchable-select.md) | the searchable select — the first component here built rather than ported, and the measurements that chose its shape |

Written during the initial port and hardening pass, 2026-08-05/06. Anything
measured is marked as measured; anything assumed says so.

A plan is what was intended going into a branch, not a record of what came out
of it. Where one and `decisions/` disagree, `decisions/` is what shipped.
