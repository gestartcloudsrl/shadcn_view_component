import { Controller } from "@hotwired/stimulus"

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
    this.render()
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
