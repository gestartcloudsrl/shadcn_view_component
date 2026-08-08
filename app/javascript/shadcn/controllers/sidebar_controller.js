import { Controller } from "@hotwired/stimulus"
import { pushLayer, removeLayer } from "shadcn/dismiss"
import { trapFocus, focusFirst, lockScroll, unlockScroll } from "shadcn/focus"
import * as topLayer from "shadcn/top_layer"

// Upstream's own name and lifetime (vendor/shadcn/ui/sidebar.tsx:28-29).
const COOKIE = "sidebar_state"
const COOKIE_MAX_AGE = 60 * 60 * 24 * 7
const SHORTCUT = "b"

// Not a number this port chose: upstream's desktop tree carries `md:block`
// (vendor/shadcn/ui/sidebar.tsx:210), and `md` is 768px in Tailwind's default
// scale. Nothing had to be vendored to learn it.
const MOBILE_QUERY = "(max-width: 767px)"

// Radix has no Sidebar — shadcn builds it on its own React context
// (vendor/shadcn/ui/sidebar.tsx:56), so this controller has no Radix source to
// answer to, only shadcn's own.
//
// The state is small: expanded or collapsed on desktop, and a separate
// ephemeral flag on mobile that is deliberately never persisted.
export default class extends Controller {
  static targets = [ "sidebar", "trigger" ]
  static values = { open: Boolean, openMobile: Boolean }

  connect() {
    // Bound on `window` rather than on the element, so it fires wherever focus
    // happens to be — which is what upstream does (sidebar.tsx:96-111), and the
    // point of a shortcut. Removed again in `disconnect()`: Turbo tears
    // controllers down on every navigation, and a listener left behind would
    // accumulate one per visit.
    this.onKeydown = (event) => {
      if (event.key !== SHORTCUT) return
      // A bare "b" is a character somebody may be typing.
      if (!event.metaKey && !event.ctrlKey) return

      event.preventDefault()
      this.toggle()
    }

    window.addEventListener("keydown", this.onKeydown)

    // Feature-detected the way `top_layer.js` treats the Popover API: without
    // matchMedia the desktop branch is the whole component.
    this.media = typeof window.matchMedia === "function" ? window.matchMedia(MOBILE_QUERY) : null
    this.onMediaChange = () => this.render()
    this.media?.addEventListener("change", this.onMediaChange)

    this.render()
  }

  disconnect() {
    window.removeEventListener("keydown", this.onKeydown)
    this.media?.removeEventListener("change", this.onMediaChange)
    this.closeMobile()
  }

  get isMobile() {
    return this.media?.matches === true
  }

  toggle() {
    // Upstream branches here rather than in the state: mobile moves an
    // ephemeral flag, desktop moves the persisted one
    // (vendor/shadcn/ui/sidebar.tsx:92-95). A phone must not overwrite what the
    // desktop remembered.
    if (this.isMobile) {
      this.openMobileValue = !this.openMobileValue
    } else {
      this.openValue = !this.openValue
      this.persist()
    }

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

    if (this.isMobile && this.openMobileValue) this.openMobile()
    else this.closeMobile()
  }

  // Everything a Sheet does, applied to markup the server already sent. The
  // element never moves, so the Stimulus actions on the links inside it stay
  // bound — which is why this port does not build a Sheet and relocate the
  // content into it, the way React renders a different tree.
  // `dialog_controller.js` composes the same three modules.
  openMobile() {
    const sidebar = this.sidebarTarget
    if (sidebar.dataset.mobile === "true") return

    sidebar.dataset.mobile = "true"
    // Undoes upstream's `hidden … md:block`, which is CSS-hidden below the
    // breakpoint because React renders a different tree there rather than
    // showing this one. Inline beats the utility without having to out-specify
    // `md:block` at every other width, and removing the property below restores
    // the class exactly.
    sidebar.style.display = "block"

    topLayer.enable(sidebar)
    topLayer.show(sidebar)
    lockScroll()
    this.releaseFocus = trapFocus(sidebar, this.hasTriggerTarget ? this.triggerTarget : undefined)
    focusFirst(sidebar)
    this.layer = pushLayer({
      element: sidebar,
      // Without the trigger as an anchor, the very click that opens the sheet
      // reaches the dismiss layer as an outside click and closes it again.
      anchors: this.hasTriggerTarget ? [ this.triggerTarget ] : [],
      onDismiss: () => {
        this.openMobileValue = false
        this.render()
      }
    })
  }

  closeMobile() {
    if (!this.hasSidebarTarget) return

    const sidebar = this.sidebarTarget
    if (sidebar.dataset.mobile !== "true") return

    delete sidebar.dataset.mobile
    sidebar.style.removeProperty("display")

    topLayer.hide(sidebar)
    unlockScroll()
    this.releaseFocus?.()
    this.releaseFocus = null
    if (this.layer) removeLayer(this.layer)
    this.layer = null
  }
}
