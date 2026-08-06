import { Controller } from "@hotwired/stimulus"
import { uniqueId } from "shadcn/id"

// Radix's Collapsible. `--radix-collapsible-content-height` is published so
// height transitions have something to animate towards.
export default class extends Controller {
  static targets = [ "trigger", "content" ]
  static values = { open: Boolean, disabled: Boolean }

  connect() {
    this.render()
  }

  toggle() {
    if (this.disabledValue) return

    this.openValue = !this.openValue
    this.render()
    this.dispatch("toggle", { detail: { open: this.openValue } })
  }

  render() {
    const state = this.openValue ? "open" : "closed"

    this.element.dataset.state = state
    if (this.disabledValue) this.element.dataset.disabled = ""

    if (this.hasTriggerTarget) {
      this.triggerTarget.dataset.state = state
      this.triggerTarget.setAttribute("aria-expanded", String(this.openValue))
      if (this.hasContentTarget) {
        this.triggerTarget.setAttribute("aria-controls", this.contentId)
      }
    }

    if (!this.hasContentTarget) return

    const content = this.contentTarget
    content.id = this.contentId
    content.dataset.state = state
    content.hidden = !this.openValue

    if (this.openValue) {
      content.style.setProperty(
        "--radix-collapsible-content-height",
        `${content.scrollHeight}px`
      )
    }
  }

  get contentId() {
    this._contentId ||= this.contentTarget.id || uniqueId("shadcn-collapsible")
    return this._contentId
  }
}
