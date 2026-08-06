import { Controller } from "@hotwired/stimulus"
import { uniqueId } from "shadcn/id"
import { FloatingLayer } from "shadcn/floating"

// Radix's Tooltip: opens on hover or focus, closes on leave, blur or Escape,
// and never takes focus itself.
export default class extends Controller {
  static targets = [ "trigger", "content" ]
  static values = {
    side: { type: String, default: "top" },
    align: { type: String, default: "center" },
    sideOffset: { type: Number, default: 0 },
    delay: { type: Number, default: 0 }
  }

  connect() {
    if (!this.hasContentTarget || !this.hasTriggerTarget) return

    this.contentTarget.hidden = true
    this.contentTarget.setAttribute("role", "tooltip")
    this.contentTarget.id ||= uniqueId("shadcn-tooltip")

    this.layer = new FloatingLayer({
      trigger: this.triggerTarget,
      content: this.contentTarget,
      prefix: "tooltip",
      side: this.sideValue,
      align: this.alignValue,
      sideOffset: this.sideOffsetValue,
      onOpen: () => this.triggerTarget.setAttribute("aria-describedby", this.contentTarget.id),
      onClose: () => this.triggerTarget.removeAttribute("aria-describedby")
    })
  }

  disconnect() {
    this.cancel()
    if (this.layer) this.layer.destroy()
  }

  show() {
    this.cancel()
    if (this.delayValue > 0) {
      this.timer = setTimeout(() => this.layer.show(), this.delayValue)
    } else {
      this.layer.show()
    }
  }

  hide() {
    this.cancel()
    this.layer.hide()
  }

  cancel() {
    if (this.timer) clearTimeout(this.timer)
    this.timer = null
  }
}
