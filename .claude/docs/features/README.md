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
| [navigation-menu.md](navigation-menu.md) | **adapted** | upstream's shared viewport needs a portal, so this ships the `viewport={false}` configuration shadcn also supports |
| [message-scroller.md](message-scroller.md) | **adapted** | shadcn's own primitive rather than a Radix one; two surfaces deliberately not reproduced, and one difference server rendering forces |

Components with a known divergence but no file yet — write one before claiming
anything about them:

- **select** — *extended*: `searchable:` is this gem's own component
  (`decisions/01-architecture.md`). Everything else measured against Radix
  matches, including the typeahead.
- **dropdown-menu** — *extended*: `loop:` exposes what Radix has as a prop and
  shadcn does not pass.
- **attachment** — *1:1 in markup, with a caveat a host should know*. Three of
  its classes are shadcn's own CSS rather than Tailwind's and are reproduced in
  `shadcn.css` from the served stylesheet, with no vendored source to diff
  against (`decisions/01-architecture.md`). And its error-state description
  carries upstream's `text-destructive/80`, which axe measures at 4.36:1 where
  AA wants 4.5 — kept, because changing it would emit a class upstream does not,
  and named as an exception in `spec/system/accessibility_spec.rb`.
- **context-menu** — *1:1 in markup; no controller of its own*. Measured against
  `dropdown-menu.tsx`: the two declare the same fifteen slots and eleven carry
  byte-identical classes once the prefix is normalised, so most of this family
  **is** the dropdown's restamped, and one controller drives both — the same
  relationship `Sheet` has with `Dialog` here. What differs is the way in: a
  `contextmenu` event opens the panel at the *pointer*, so `FloatingLayer` grew
  an optional `anchor` that is measured instead of the trigger. `content` and
  `sub-content` keep their own class strings, because those read
  `--radix-context-menu-*` and inheriting the dropdown's would leave them
  reading variables nothing sets — which `parity_spec` cannot see, since it asks
  whether a token appears anywhere in the family and not whether it appears on
  the right element.

  **Submenus close on a time-based grace, not a shaped one.** Radix draws a
  polygon from the point where the pointer left the trigger to the panel's
  edges and honours it only while the pointer is moving *toward* the panel
  (`vendor/radix/ui/menu.tsx:1136-1160`). This port grants the same 300ms
  without the direction test, which is more forgiving and never less: a pointer
  heading away still gets the delay it would not have had upstream. Before it
  existed, nothing closed a hovered submenu at all — it waited for Escape or a
  click outside.
- **menubar** — *1:1 in markup; its own controller over the dropdown's*. Each
  menu is a `shadcn--dropdown-menu` with `prefix: "menubar"`, the same
  arrangement `context-menu` has, and eight of the sixteen slots are the
  dropdown's restamped. What is not the dropdown's is the bar: one menu open at
  a time, a name you merely *cross* switching to it once one is, a single tab
  stop moved by focus rather than left on every name, and arrows that keep
  walking the bar from inside an open panel. Those four are
  `shadcn--menubar`, and `vendor/radix/ui/menubar.tsx` — vendored while porting
  it — is what they are answerable to. `loop` defaults to **true** here and
  `false` in the dropdown, which is Radix's own split
  (`vendor/radix/ui/menubar.tsx:76`): a bar is a ring, a list is not.

  Two attributes are added to `menubar-content` that appear in neither vendored
  file — `tabindex="-1"` and `aria-orientation="vertical"` — because Radix adds
  them at runtime, through FocusScope and Menu, rather than writing them in the
  component. The dropdown's content already carried both. The `tabindex` is
  load-bearing rather than cosmetic: without it `focus()` on the panel is
  silently a no-op, so the panel never holds focus, and the arrow keys, the
  typeahead and Escape are all left listening on an element nothing types into
  — an opened menu that looks right and answers nothing.
- **slider** — *1:1 in markup, with one addition Rails needs*. Each thumb is a
  `role="slider"` with its own `aria-valuenow`, so a two-handled range is two
  controls; `aria_label:` takes one string or one per thumb, because axe fails a
  role with no name and "Price" twice names neither end. The port also renders a
  **hidden input per thumb** when given a `name:` — shadcn's file renders none,
  because in React the value is state rather than markup, and a Rails form has
  to submit something. Not reproduced: `inverted`, which Radix takes and shadcn
  never passes.
- **scroll-area** — *1:1 in markup, with four divergences worth knowing*.
  Radix is 1,189 lines against shadcn's 58, and most of it does not survive the
  crossing. **(1)** The viewport carries `tabindex="0"`, which Radix does not
  set: axe fails a scrollable region with no keyboard access, Chrome and Firefox
  make scrollers focusable themselves and Safari does not, and shadcn's own
  classes style `focus-visible` on that element. **(2)** Two of Radix's four
  `type` strategies are reproduced — `hover`, its default, and `always`; not
  `scroll` or `auto`. **(3)** A second axis is asked for with
  `orientation: :both` rather than by passing a second `<ScrollBar>` as a child,
  which relies on React's Slottable to hoist it out of the viewport. **(4)** The
  bars are hidden with `data-state` rather than unmounted, which is the same
  rule that keeps floating content in place here.
- **direction** — *ported as a module, not a component*. shadcn's file wraps
  Radix's `DirectionProvider`, which renders no DOM: React needs a context to
  read inherited state while rendering, and a Stimulus controller does not,
  because the browser has resolved `dir` before it runs. So a host writes `dir`
  on any ancestor — `<html>` included — and `tabs`, `toggle-group` and
  `radio-group` follow it. There is nothing to render and no provider to mount.
- **hover-card** — *1:1 in markup; one behaviour of Radix's not reproduced*.
  Every tabbable inside the card is taken out of the tab order, which is Radix's
  own (`vendor/radix/ui/hover-card.tsx:324-327`) and follows from the card
  having no way to be tabbed into — so do not put anything in one that is
  reachable only there. **Not reproduced:** Radix keeps the card open while text
  inside it is being selected, holding `user-select` on the body through the
  drag and refusing to close while a selection stands (`:288-321`). Without it,
  a pointer that strays off the card mid-selection closes it.
- **message, bubble, marker** — believed 1:1 in markup and variants, and *not
  assessed beyond that*. They have no behaviour to diverge in.
