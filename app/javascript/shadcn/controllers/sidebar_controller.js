import { Controller } from "@hotwired/stimulus"
import { pushLayer, removeLayer } from "shadcn/dismiss"
import { trapFocus, focusFirst, lockScroll, unlockScroll } from "shadcn/focus"
import * as topLayer from "shadcn/top_layer"
import { ExitQueue } from "shadcn/animation"

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
  static targets = [ "sidebar", "trigger", "container", "overlay" ]
  static values = { open: Boolean, openMobile: Boolean }

  connect() {
    // Holds the DOM half of a close until the sheet's slide-out has played.
    // Same module and the same reason as `dialog_controller.js`.
    this.exits = new ExitQueue()

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
    // Turbo may be detaching the element: there is nothing to animate for, and
    // the deferred teardown still has to run.
    this.exits.flushAll()
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
    //
    // Empty on the mobile branch for a second reason: upstream's mobile tree
    // has no collapsed state to carry (sidebar.tsx:182-204), and here the same
    // element serves both, so a `collapsed` left over from the desktop would
    // style the sheet as a rail of icons — or, with `offcanvas`, slide it off
    // the screen it was just opened on.
    sidebar.dataset.collapsible =
      this.openValue || this.isMobile ? "" : (sidebar.dataset.sidebarCollapsible || "offcanvas")

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

    // Reopened before the slide-out finished: both teardowns are still queued
    // and would undo an open sheet a moment after it appeared.
    if (this.hasContainerTarget) this.exits.cancel(this.containerTarget)
    if (this.hasOverlayTarget) this.exits.cancel(this.overlayTarget)

    sidebar.dataset.mobile = "true"
    // Undoes upstream's `hidden … md:block`, which is CSS-hidden below the
    // breakpoint because React renders a different tree there rather than
    // showing this one. Inline beats the utility without having to out-specify
    // `md:block` at every other width, and removing the property below restores
    // the class exactly.
    sidebar.style.display = "block"

    // `sheet-content` and `sheet-overlay` are animated by their own
    // `data-[state=…]` classes, exactly as upstream writes them; nothing else
    // here reads these two attributes.
    this.setSheetState("open")

    topLayer.enable(sidebar)
    topLayer.show(sidebar)
    lockScroll()

    // The panel, not the sheet: the overlay is a child of `sidebar`, so a layer
    // registered on `sidebar` counts a click on the dimmed backdrop as a click
    // *inside* itself and never dismisses. Upstream has no such problem — its
    // overlay is the content's sibling, portalled beside it. Here the two share
    // a parent, and the layer has to be the half that is not the backdrop.
    const panel = this.hasContainerTarget ? this.containerTarget : sidebar

    this.releaseFocus = trapFocus(panel, this.hasTriggerTarget ? this.triggerTarget : undefined)
    focusFirst(panel)
    this.layer = pushLayer({
      element: panel,
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

    // Interaction state goes now: a sheet that is sliding out must not answer
    // Escape, keep the page's scroll locked or hold focus. Only what is still
    // being *looked at* waits — the same split `floating.js` makes.
    unlockScroll()
    this.releaseFocus?.()
    this.releaseFocus = null
    if (this.layer) removeLayer(this.layer)
    this.layer = null

    this.setSheetState("closed")

    // Each element waits on its *own* animations, as the dialog's layers do.
    // Hiding the backdrop on the container's clock instead looks broken rather
    // than merely late: nothing in the compiled bundle sets
    // `animation-fill-mode`, so the moment `fade-out-0` ends the overlay snaps
    // back to a full `bg-black/50` and sits there — the panel gone, a grey
    // sheet of glass left over it — until the longer animation finishes.
    // Upstream's two clocks differ the same way, 150ms against `duration-300`.
    if (this.hasOverlayTarget) {
      this.exits.defer(this.overlayTarget, () => { this.overlayTarget.hidden = true })
    }

    // What ends the sheet is `data-mobile` going away — it is what
    // `group-data-[mobile=true]:flex` reads — so it has to outlast the
    // slide-out rather than start it.
    const finish = () => {
      delete sidebar.dataset.mobile
      sidebar.style.removeProperty("display")

      topLayer.hide(sidebar)
      // Paired with the `enable` above, and not optional: this element is laid
      // out around, so leaving it a popover leaves it `position: fixed` and the
      // page draws over the desktop sidebar from then on.
      topLayer.disable(sidebar)
    }

    if (this.hasContainerTarget) this.exits.defer(this.containerTarget, finish)
    else finish()
  }

  // The overlay is `hidden` in the server's markup and stays that way on
  // desktop, where nothing ever opens a sheet.
  setSheetState(state) {
    if (this.hasContainerTarget) this.containerTarget.dataset.state = state
    if (!this.hasOverlayTarget) return

    if (state === "open") this.overlayTarget.hidden = false
    this.overlayTarget.dataset.state = state
  }
}
