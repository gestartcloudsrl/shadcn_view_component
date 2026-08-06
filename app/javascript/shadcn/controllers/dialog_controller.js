import { Controller } from "@hotwired/stimulus"
import { uniqueId } from "shadcn/id"
import { pushLayer, removeLayer } from "shadcn/dismiss"
import { trapFocus, focusFirst, lockScroll, unlockScroll } from "shadcn/focus"
import * as topLayer from "shadcn/top_layer"

// Radix's Dialog, shared by Dialog, AlertDialog and Sheet: focus is trapped in
// the content, body scrolling is locked, and Escape closes it — except for
// AlertDialog, which Radix keeps dismiss-proof on outside clicks.
//
// Radix portals the overlay and content onto `document.body`; we deliberately
// leave them where they are. Both are `position: fixed` and the root is
// `display: contents`, so they still lay out against the viewport, and keeping
// them inside the controller's element is what lets the Stimulus actions on
// the close buttons keep working. (The one case this gives up is a host page
// that puts a `transform`/`filter`/`contain` ancestor above the dialog, which
// would become the containing block.)
export default class extends Controller {
  static targets = [ "trigger", "overlay", "content" ]
  static values = {
    open: Boolean,
    modal: { type: Boolean, default: true },
    dismissable: { type: Boolean, default: true }
  }

  connect() {
    this.releaseFocus = null
    this.layer = null

    if (this.hasContentTarget) this.contentTarget.hidden = !this.openValue
    if (this.hasOverlayTarget) this.overlayTarget.hidden = !this.openValue

    this.render()
    if (this.openValue) this.show()
  }

  disconnect() {
    this.teardown()
  }

  open() {
    this.show()
  }

  close() {
    this.hide()
  }

  toggle() {
    this.openValue ? this.hide() : this.show()
  }

  show() {
    if (!this.hasContentTarget || this.layer) return

    this.previouslyFocused = document.activeElement
    this.openValue = true
    this.render()

    if (this.modalValue) lockScroll()

    this.releaseFocus = trapFocus(this.contentTarget, this.previouslyFocused)
    focusFirst(this.contentTarget)

    this.layer = pushLayer({
      element: this.contentTarget,
      anchors: this.hasTriggerTarget ? [ this.triggerTarget ] : [],
      onDismiss: ({ reason }) => {
        if (reason === "pointerdown" && !this.dismissableValue) return
        this.hide()
      }
    })

    this.dispatch("open")
  }

  hide() {
    if (!this.layer) return

    this.teardown()
    this.openValue = false
    this.render()
    this.dispatch("close")
  }

  teardown() {
    if (this.layer) removeLayer(this.layer)
    this.layer = null

    if (this.releaseFocus) this.releaseFocus()
    this.releaseFocus = null

    if (this.modalValue) unlockScroll()
  }

  render() {
    const state = this.openValue ? "open" : "closed"

    if (this.hasContentTarget) {
      this.contentTarget.id ||= uniqueId("shadcn-dialog")
      this.contentTarget.dataset.state = state
      this.contentTarget.hidden = !this.openValue
    }

    if (this.hasOverlayTarget) {
      this.overlayTarget.dataset.state = state
      this.overlayTarget.hidden = !this.openValue
    }

    // Overlay first, content second: the top layer stacks in the order things
    // are shown, so the dialog ends up above its own backdrop.
    this.promote(this.hasOverlayTarget && this.overlayTarget)
    this.promote(this.hasContentTarget && this.contentTarget)

    if (!this.hasTriggerTarget) return

    this.triggerTarget.dataset.state = state
    this.triggerTarget.setAttribute("aria-expanded", String(this.openValue))
    this.triggerTarget.setAttribute("aria-haspopup", "dialog")
    if (this.hasContentTarget) {
      this.triggerTarget.setAttribute("aria-controls", this.contentTarget.id)
    }
  }

  // A modal inside a `sticky z-40` header or an `isolate` card would otherwise
  // be buried by whatever sits above that stacking context.
  promote(element) {
    if (!element) return

    topLayer.enable(element)
    this.openValue ? topLayer.show(element) : topLayer.hide(element)
  }
}
