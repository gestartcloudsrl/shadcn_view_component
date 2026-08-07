import { Controller } from "@hotwired/stimulus"
import { uniqueId } from "shadcn/id"
import { FloatingLayer } from "shadcn/floating"
import { trapFocus, focusFirst } from "shadcn/focus"

// Radix's Popover: a `role="dialog"` layer anchored to its trigger.
export default class extends Controller {
  static targets = [ "trigger", "content", "anchor" ]
  static values = {
    open: Boolean,
    side: { type: String, default: "bottom" },
    align: { type: String, default: "center" },
    sideOffset: { type: Number, default: 4 },
    alignOffset: { type: Number, default: 0 },
    modal: Boolean
  }

  connect() {
    if (!this.hasContentTarget || !this.hasTriggerTarget) return

    this.contentTarget.hidden = true
    this.contentTarget.id ||= uniqueId("shadcn-popover")

    // The id is generated here, so the server has nothing to point this at.
    this.triggerTarget.setAttribute("aria-controls", this.contentTarget.id)
    this.triggerTarget.dataset.state = "closed"

    this.layer = new FloatingLayer({
      trigger: this.hasAnchorTarget ? this.anchorTarget : this.triggerTarget,
      content: this.contentTarget,
      prefix: "popover",
      side: this.sideValue,
      align: this.alignValue,
      sideOffset: this.sideOffsetValue,
      alignOffset: this.alignOffsetValue,
      onOpen: () => {
        this.triggerTarget.setAttribute("aria-expanded", "true")
        this.releaseFocus = trapFocus(this.contentTarget, this.triggerTarget)
        focusFirst(this.contentTarget)
      },
      onClose: () => {
        this.triggerTarget.setAttribute("aria-expanded", "false")
        if (this.releaseFocus) this.releaseFocus()
        this.releaseFocus = null
      }
    })

    if (this.openValue) this.layer.show()
  }

  disconnect() {
    if (this.layer) this.layer.destroy()
  }

  toggle() {
    this.layer.toggle()
  }

  open() {
    this.layer.show()
  }

  close() {
    this.layer.hide()
  }
}
