import { Controller } from "@hotwired/stimulus"

// Upstream's own name and lifetime (vendor/shadcn/ui/sidebar.tsx:28-29).
const COOKIE = "sidebar_state"
const COOKIE_MAX_AGE = 60 * 60 * 24 * 7

// Radix has no Sidebar — shadcn builds it on its own React context
// (vendor/shadcn/ui/sidebar.tsx:56), so this controller has no Radix source to
// answer to, only shadcn's own.
//
// The state is small: expanded or collapsed on desktop, and a separate
// ephemeral flag on mobile that is deliberately never persisted.
export default class extends Controller {
  static targets = [ "sidebar", "trigger" ]
  static values = { open: Boolean }

  connect() {
    this.render()
  }

  toggle() {
    this.openValue = !this.openValue
    this.persist()
    this.render()
  }

  // Written, never read. A Rails layout reads it and passes the result back as
  // the `open` value, the way a Next.js layout does with `defaultOpen`
  // (vendor/shadcn/ui/sidebar.tsx:86) — which is the whole reason this is a
  // cookie and not `localStorage`: the server has to be able to render the
  // sidebar already collapsed, and on this component the alternative is a
  // full-width layout shift on every page.
  //
  // `samesite=lax` is this port's one addition. Upstream's line carries no
  // SameSite, and `theme.js` here already writes its cookie with it, so
  // matching upstream character for character would leave one library
  // disagreeing with itself.
  //
  // No `try`/`catch`: a blocked cookie assignment is a silent no-op, not an
  // exception. `theme.js` wraps `localStorage`, which does throw in private
  // browsing, and leaves its own cookie line outside the guard for this reason.
  persist() {
    document.cookie =
      `${COOKIE}=${this.openValue}; path=/; max-age=${COOKIE_MAX_AGE}; samesite=lax`
  }

  // Named `render` because `index.js` re-runs exactly that on every `shadcn--*`
  // controller after `turbo:morph`, which is what puts a controller back in
  // agreement with markup the server has just rewritten underneath it.
  render() {
    if (!this.hasSidebarTarget) return

    const sidebar = this.sidebarTarget

    sidebar.dataset.state = this.openValue ? "expanded" : "collapsed"

    // Upstream writes this empty while expanded and fills it only when
    // collapsed (vendor/shadcn/ui/sidebar.tsx:212). The classes match on
    // `group-data-[collapsible=offcanvas]:…`, so filling it always would style
    // an open sidebar as a closed one. The value to collapse *to* therefore
    // cannot live here; it lives in `data-sidebar-collapsible`.
    sidebar.dataset.collapsible =
      this.openValue ? "" : (sidebar.dataset.sidebarCollapsible || "offcanvas")
  }
}
