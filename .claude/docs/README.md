# Working notes

`CLAUDE.md` at the repo root says *how* to work here. `decisions/` says *why*,
`todo.md` says what is left, `features/` says per component what is upstream's
and what is ours, `specs/` holds a design agreed before a plan was written, and
`plans/` holds the plan a branch was worked out from before any of it was
written.

| | |
|---|---|
| [decisions/01-architecture.md](decisions/01-architecture.md) | project shape, the cva/`cn` mapping, `Shadcn::` namespacing, no-npm rule, the `part` macro, FormBuilder, performance, tooling |
| [decisions/02-javascript.md](decisions/02-javascript.md) | how Radix was reimplemented: `display: contents` roots, why nothing is portalled, the Popover API top layer, `turbo:morph` |
| [decisions/03-testing.md](decisions/03-testing.md) | what each spec proves and does **not**, the rejected reverse-parity check, system-spec pitfalls, what each `vendor/` reference is worth and why a control measurement is not optional |
| [decisions/04-bugs-fixed.md](decisions/04-bugs-fixed.md) | the council's findings and their fixes — a list of things not to reintroduce |
| [features/README.md](features/README.md) | per component: 1:1, adapted, extended or ours — the answer a host wants, written to be lifted into the public README |
| [todo.md](todo.md) | open work, ordered by what blocks a release, plus what is deliberately not being done |
| [plans/2026-08-06-exit-animations.md](plans/2026-08-06-exit-animations.md) | the plan the exit-animation work was executed from: the three closing paths, what each way of interrupting a half-finished close does, the reduced-motion collapse |
| [plans/2026-08-07-plain-ports-group-a.md](plans/2026-08-07-plain-ports-group-a.md) | vendoring the 27 unported sources, and porting the four that are markup only |
| [plans/2026-08-07-smaller-things.md](plans/2026-08-07-smaller-things.md) | closing eleven of the twelve entries under *Smaller things* |
| [specs/2026-08-08-sidebar-mobile-rendering-design.md](specs/2026-08-08-sidebar-mobile-rendering-design.md) | how the Sidebar port decides between its desktop tree and its mobile Sheet, given a server that cannot know the viewport |
| [plans/2026-08-08-searchable-select.md](plans/2026-08-08-searchable-select.md) | the searchable select — the first component here built rather than ported, and the measurements that chose its shape |
| [plans/2026-08-08-sidebar-behaviour.md](plans/2026-08-08-sidebar-behaviour.md) | the Sidebar's first branch: the Stimulus controller and the contract page it was driven from, before any of the 23 parts existed |
| [features/message-scroller.md](features/message-scroller.md) | the message scroller: 2,439 lines of shadcn's own primitive measured before porting, the two surfaces deliberately left out, and the one place server rendering forces a difference |
| [features/navigation-menu.md](features/navigation-menu.md) | why the navigation menu ships one of upstream's two configurations, and the two timing specs that asserted nothing until a mutation said so |
| [features/sidebar.md](features/sidebar.md) | the Sidebar as shipped — what upstream's three-tree render became here, and the four things that one tree cost |
| [features/drawer.md](features/drawer.md) | the Drawer: vaul's two release thresholds, the four features deliberately left out, the stylesheet that had to come with it, and the branch no spec here can reach |
| [features/form.md](features/form.md) | why `form.tsx` is a FormBuilder here rather than components, part by part, and the seven divergences that follow |
| [features/carousel.md](features/carousel.md) | the Carousel without embla: the six things shadcn asks of it, what a scroller answers instead, and what is left out |

Written during the initial port and hardening pass, 2026-08-05/06. Anything
measured is marked as measured; anything assumed says so.

A plan is what was intended going into a branch, not a record of what came out
of it. Where one and `decisions/` disagree, `decisions/` is what shipped.
