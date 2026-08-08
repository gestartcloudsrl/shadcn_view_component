# Sidebar

**Verdict: ours, and adapted where it touches upstream.**

**Status: in progress.** The behaviour ships; none of the 24 components do. What
is written below about markup describes the contract they will emit, and lives
today in `test/dummy/app/views/sidebar/show.html.erb` rather than in the gem.

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

## Added

Nothing yet. `collapsible`, `variant` and `side` are upstream's own props, and
the controller reads them rather than inventing any.

## Not reproduced

- **`collapsible="none"`** and the `icon` variant — class-only, and they belong
  with the components rather than the behaviour.
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
| every class string matching upstream's | `spec/parity_spec.rb` once the components exist |
| no class rendered that upstream has dropped | `spec/reverse_parity_spec.rb`, same condition |

The reasoning behind the shape is in
[specs/2026-08-08-sidebar-mobile-rendering-design.md](../specs/2026-08-08-sidebar-mobile-rendering-design.md);
this file is the summary a host needs, not the argument.
