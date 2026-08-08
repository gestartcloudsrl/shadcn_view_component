# Sidebar: how the mobile branch is decided

**Status:** approved, 2026-08-08. Feeds an implementation plan; not itself a plan.

**The question:** shadcn's `Sidebar` renders three different DOM trees and picks
between them at runtime with `useIsMobile()`, a `matchMedia` hook. This port
renders on a server that cannot know the viewport. What replaces the branch?

## What upstream actually does

Read off `vendor/shadcn/ui/sidebar.tsx`, 726 lines, 24 parts — the largest
component in shadcn. It composes sheet, tooltip, button, input, separator and
skeleton, all six already ported here.

`Sidebar` branches three ways (`:154`):

- `collapsible === "none"` — a plain `<div>`, no behaviour
- `isMobile` — a `Sheet`, width `18rem`, with the sidebar's children inside
- otherwise — the desktop tree: `sidebar` > `sidebar-gap` + `sidebar-container` >
  `sidebar-inner`

State lives in `SidebarProvider` (`:56`) and is small: `open`, `openMobile`,
`state` derived as `expanded`/`collapsed`, plus `isMobile`. `setOpen` writes
`sidebar_state` with a seven-day max-age (`:86`). `toggleSidebar` moves
`openMobile` on mobile and `open` on desktop, so **the mobile state is never
persisted**. The keyboard shortcut is `cmd/ctrl+b`.

**The component never reads the cookie.** Line 86 is the only mention. Reading is
the host's job — a Next.js layout reads it and passes `defaultOpen`, which
otherwise defaults to `true`. A deleted cookie therefore degrades to "expanded"
and the next toggle writes it again; nothing can desync, because there is only
one store.

## Decisions

### One tree, rendered by the server; the Sheet happens in place

Rejected: rendering both trees and hiding one with CSS. It works without
JavaScript, but a real sidebar holds a navigation tree, and putting it in the
DOM twice is a cost paid on every page by every visitor.

Rejected: having the controller build a Sheet and move the content into it. That
is closest to React, and it collides with a decision this project already made —
*nothing is portalled*, because moving content out of the controller's element
unbinds the Stimulus actions inside it (`decisions/02-javascript.md`). A sidebar
is full of links and buttons.

**Chosen:** the server renders the desktop tree. Below the breakpoint the
controller gives that same DOM the behaviour of a Sheet — top layer, dismiss,
focus trap, side entrance — without moving it. This is the same move the gem
already makes for every floating layer: promote in place with the Popover API.

The cost, accepted deliberately: on a phone, before JavaScript runs, there is no
sidebar. The gem already requires Stimulus for every layer, so this adds no new
dependency, but it is a real difference from upstream, where the server sends the
Sheet markup.

**A detail that has to be handled rather than inherited:** upstream's desktop
tree carries `hidden text-sidebar-foreground md:block` (`:210`), so below `md` it
is CSS-hidden *already* — React simply never renders it there. Mounting Sheet
behaviour on that element without more would animate something invisible.

The controller therefore has to make it visible on the mobile branch, and the
implementation plan has to pick how: an inline `display` while the mobile sheet
is open is the smallest change and reverses cleanly on close; a class toggle
would collide with `md:block`'s specificity at the boundary. Whichever it is,
this is the one place where a reader comparing markup to upstream will see a
difference that is not a class string — and it exists because upstream deletes
the element and this port keeps it.

### The breakpoint is `md`, and it is derivable

`useIsMobile` lives in `hooks/use-mobile`, which is not vendored — only `ui/` and
`examples/` are. It does not need to be: the desktop tree's own `md:block` is the
breakpoint, and `md` is 768px in Tailwind's default scale. No configurable value
is invented, and nothing new is vendored.

### The cookie, with `SameSite`

Upstream writes it bare:

```js
document.cookie = `sidebar_state=${openState}; path=/; max-age=604800`
```

This port adds `samesite=lax`, which is a one-word divergence and the only one
in the persistence layer. Two reasons: `theme.js` in this gem already writes its
mirror that way, so copying upstream verbatim would make two cookies written by
one library disagree about it; and a library writing a cookie without `SameSite`
into an application it will never see is the shape of thing this project's second
constraint exists to catch.

**No `localStorage`.** `theme.js` keeps `localStorage` as its source of truth and
mirrors to a cookie, which is why deleting one there leaves the other in charge.
The sidebar has a single store, so a deleted cookie is clean — it resets to the
default. Adding a second store would import a disagreement upstream does not
have.

## Scope of the first branch

Behaviour only: a Stimulus controller and its specs. **No new ViewComponents.**

That cannot mean no markup at all — a system spec needs a page. It means the
markup is hand-written, and it earns its place twice: it drives the controller
now, and it is **the contract the 24 parts must satisfy** when they arrive. Every
attribute in it is one a future component has to emit.

Two homes for it, both wanted:

- `test/dummy/config/routes.rb` gains `get "sidebar"`, with a controller and view
  following `turbo_probe`, which exists for the same reason: a full-page layout
  is something a Lookbook preview cannot give. This is also where a human looks
  at it.
- The system spec drives that page.

The remaining sixteen parts — Menu, Group, Sub, Skeleton, Badge and the rest —
are markup and classes, and follow in a branch that risks nothing.

## The contract the controller expects

On `[data-slot="sidebar-wrapper"]`, which is where upstream sets
`--sidebar-width: 16rem` and `--sidebar-width-icon: 3rem` (`:129-145`):

| | |
|---|---|
| values | `open`, `openMobile` (never persisted) |
| reads | `data-collapsible`, `data-variant`, `data-side` off the sidebar element |
| actions | toggle; `cmd/ctrl+b` bound on `window` |

It writes four attributes on `[data-slot="sidebar"]`, and every Tailwind class in
the family reads them: `data-state`, `data-collapsible`, `data-variant`,
`data-side`.

`data-collapsible` has a trap worth naming. Upstream writes it **empty while
expanded** and only fills it when collapsed —
`data-collapsible={state === "collapsed" ? collapsible : ""}` (`:212`). The
classes match on `group-data-[collapsible=icon]:…`, so writing it unconditionally
would apply the collapsed styling to an open sidebar.

## Degradation

- **No JavaScript** — the sidebar stays as the server rendered it, from the
  cookie. Usable on desktop, not toggleable; absent on mobile, as above.
- **Cookies blocked** — the write fails silently and state resets each load.
  `theme.js` already wraps its storage access for the same reason.
- **No `matchMedia`** — feature-detect and stay on the desktop branch, the way
  `top_layer.js` treats the Popover API.
- **Turbo morph** — the state lives in attributes, which a morph refresh
  rewrites. The controller re-syncs on `turbo:morph`, the convention already
  documented in `decisions/02-javascript.md`. Without it a refresh silently
  reverts the sidebar while the controller believes otherwise.

## Testing

A system spec against `/sidebar`: toggling, the cookie being written, the
keyboard shortcut, and the mobile branch driven by **resizing the window for
real**, since that is what `matchMedia` observes.

Every behaviour verified by mutation before it is trusted — three specs in this
session passed with the feature removed, and the standard exists because of them.
`stimulus_contract_spec` picks up values, targets and actions on its own once the
markup exists.

## Not in this design

- The sixteen leaf parts.
- Server-side viewport detection. The host may do it and pass `default_open:`;
  the gem takes no position and ships no such thing.
- `localStorage`, per above.
