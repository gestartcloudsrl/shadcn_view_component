# Per-component: what is upstream's, and what is ours

One file per component, answering the question a host actually asks — *how does
your version differ from shadcn's?* — in a form that can be lifted into the
public README rather than summarised again.

The gem's pitch is a 1:1 port. That is true of most of it and not of all of it,
and the difference is currently spread across `decisions/01-architecture.md`,
comments in the components, and the `ours` list in `spec/reverse_parity_spec.rb`.
Nowhere can you read one component's answer end to end.

## The verdict, and what each word promises

Every entry opens with one of four. They are ordered by distance from upstream.

| | |
|---|---|
| **1:1** | Markup, attributes and behaviour reproduce upstream. The only differences are the ones Rails forces on every component here: `Shadcn::` namespacing, slots instead of JSX children, snake_case keywords. |
| **adapted** | The same component, with a decision changed because server rendering or this gem's own architecture left no choice. Each one is named, with what forced it. |
| **extended** | Upstream's component, plus API upstream does not have. The addition is always opt-in and always defaults to upstream's behaviour. |
| **ours** | No upstream equivalent to be 1:1 with. Built here, taking whatever shape could be taken. |

A component can be more than one thing at once — the Select is *extended* by
`searchable:` and *1:1* everywhere else — so the verdict names the strongest
claim that applies, and the entry says where it stops.

## What is not in these files

**Class-level divergences.** `spec/reverse_parity_spec.rb` already enumerates
every class this port renders that no vendored source contains, and it is
enforced: add one without declaring it and the suite fails. Repeating that list
here would create a copy nobody updates. These files carry what a machine cannot
— the reasoning, and the divergences that are not classes: attributes, behaviour,
API.

**Anything unmeasured.** An absent entry means *not yet assessed*, never "1:1".
The port is around thirty families and four have been examined closely enough to
write down; claiming the rest match would be exactly the kind of sentence this
project keeps catching itself in.

## Index

| Component | Verdict | Why |
|---|---|---|
| [sidebar.md](sidebar.md) | **ours** / adapted | no Radix Sidebar exists; the runtime mobile branch cannot survive server rendering |

Components with a known divergence but no file yet — write one before claiming
anything about them:

- **select** — *extended*: `searchable:` is this gem's own component
  (`decisions/01-architecture.md`). Everything else measured against Radix
  matches, including the typeahead.
- **dropdown-menu** — *extended*: `loop:` exposes what Radix has as a prop and
  shadcn does not pass.
