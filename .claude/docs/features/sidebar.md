# Sidebar

**Verdict: ours, and adapted where it touches upstream.**

**Status: complete.** All 23 renderable parts ship, `tooltip:` included. The
twenty-fourth export upstream is `useSidebar`, a React hook whose job here is
the Stimulus controller.

**Upstream:** `vendor/shadcn/ui/sidebar.tsx` — 726 lines, 24 parts, the largest
component shadcn publishes. It composes sheet, tooltip, button, input, separator
and skeleton, all six already ported here.

---

## Why this one is not a port

Radix has no Sidebar. shadcn builds it on its own React context
(`sidebar.tsx:56`), so there is no primitive whose behaviour this could
reproduce — the rule that upstream wins on markup has nothing to point at for
half the component.

What could be taken was taken: every class string, every `data-slot`, the four
state attributes, the cookie name and lifetime, the keyboard shortcut, the three
widths. What could not is the part React does at runtime.

## Adapted, and what forced it

### One DOM tree instead of three

**Upstream** renders three different trees and picks between them while
rendering: a plain `<div>` when `collapsible="none"`, a `Sheet` when
`useIsMobile()` is true, and the desktop tree otherwise (`sidebar.tsx:154`).

**Here** the server renders the desktop tree, and below the breakpoint the
controller gives that same DOM the behaviour of a Sheet — top layer, dismiss,
focus trap, scroll lock — without moving it.

**What forced it:** the server cannot know the viewport, and the two obvious
alternatives were both worse. Rendering both trees puts a navigation tree in the
DOM twice, on every page, for every visitor. Building a Sheet in JavaScript and
moving the content into it is closest to React and collides with a decision this
gem already made: nothing is portalled, because moving content out of a
controller's element unbinds the Stimulus actions inside it — and a sidebar is
made of links and buttons.

**One consequence to know if you write your own markup:** upstream's desktop
tree carries `hidden … md:block`, which is why it is invisible below the
breakpoint — React never renders it there, so upstream never has to undo it. This
port does, with an inline `display` set while the mobile sheet is open and
removed when it closes. If you override that element's `display` yourself, that
is the interaction to watch.

**What it costs you:** on a phone, before JavaScript runs, there is no sidebar.
The gem already requires Stimulus for every floating layer, so this adds no new
dependency, but it is a real difference: upstream's server sends the Sheet
markup, and this one does not.

### The open state is the host's to render

**Upstream** writes a `sidebar_state` cookie and never reads it back
(`sidebar.tsx:86`). Reading is the application's job — their Next.js layout reads
it and passes `defaultOpen`.

**Here** the same, unchanged: the controller writes, and a Rails layout reads
`cookies["sidebar_state"]` and passes the result back in. Nothing in the gem
parses cookies.

**Why it is a cookie and not `localStorage`:** the server has to be able to
render the sidebar already collapsed. `localStorage` is invisible to it, so the
first paint would always be the default and the client would correct it after
Stimulus boots — on this component a full-width layout shift, since collapsing
moves the panel off-canvas and takes the gap to `w-0`.

**One divergence in that layer:** the cookie is written with `samesite=lax`,
where upstream's line has none. `theme.js` in this gem already writes its own
cookie that way, so matching upstream character for character would have left one
library disagreeing with itself.

### The menu-button tooltip hides in CSS, not at render

**Upstream** wraps the button in a Tooltip and hides the content with a prop:
`hidden={state !== "collapsed" || isMobile}` (`sidebar.tsx:534-542`). Both halves
are React state, re-read on every render.

**Here** the same two conditions are classes on the panel's own group —
`group-data-[state=expanded]:hidden group-data-[mobile=true]:hidden` — because
neither is knowable when the server renders, and both are already written onto
the panel as attributes for the rest of the family's classes to read. The
component's own element still comes out as `sidebar-menu-button`: the tooltip
trigger's attributes are merged onto it rather than wrapping it, so `data-slot`,
`data-sidebar` and the caller's own attributes all survive.

**What that cost.** Upstream's version is positioned by floating-ui, whose
`autoUpdate` watches the reference element for resizes. Ours positioned once, on
open — and this is the one component where the anchor changes width underneath
an open layer: focus a menu row, press ⌘B, and the button goes from the panel's
width to the icon's while the tooltip is showing. The label stayed where the wide
button used to end, 207px out from the icon it names. `FloatingLayer` now
observes its anchor, which fixes it for every popper-based component rather than
this one. The measurement is in `spec/system/sidebar_spec.rb`.

## Added

Nothing. `collapsible`, `variant`, `side`, `size`, `variant` on the menu button
and `show_on_hover` on the menu action are all upstream's own props, renamed
only where Ruby conventions demand it — `isActive` becomes `active:`,
`showIcon` becomes `show_icon:`.

## Not reproduced

- **`asChild`.** Five parts take it upstream, to render as a link instead of a
  button. This gem answers it everywhere with `as:` — documented on
  `ApplicationViewComponent#initialize` as exactly that — so the prop needs no
  counterpart of its own. `MenuButton::Component.new(as: :a, href: …)` is what
  upstream writes as `<SidebarMenuButton asChild><a …>`.
- **An exit animation for the mobile sheet.** `dialog_controller.js` runs its
  closes through `ExitQueue`; this one hides immediately. With nothing animating,
  `ExitQueue` would take its synchronous branch anyway — worth revisiting when
  the components bring real animation classes.
- **Server-side viewport detection.** A host may do it and pass `open:`; the gem
  takes no position and ships nothing for it.

## Where each claim is enforced

| Claim | Enforced by |
|---|---|
| the four state attributes, and `data-collapsible` empty while expanded | `spec/system/sidebar_spec.rb`, mutation-verified |
| the cookie, its name and its values | same file, mutation-verified |
| `cmd/ctrl+b`, and a bare `b` left alone | same file, mutation-verified |
| the mobile sheet opening, and Escape dismissing it | same file, mutation-verified |
| a phone never writing the desktop cookie | same file, mutation-verified |
| every class string matching upstream's | `spec/parity_spec.rb` once the components exist |
| no class rendered that upstream has dropped | `spec/reverse_parity_spec.rb`, same condition |

The reasoning behind the shape is in
[specs/2026-08-08-sidebar-mobile-rendering-design.md](../specs/2026-08-08-sidebar-mobile-rendering-design.md);
this file is the summary a host needs, not the argument.
