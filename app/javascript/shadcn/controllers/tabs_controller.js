import { Controller } from "@hotwired/stimulus"
import { directionAwareKey, readDirection } from "shadcn/direction"
import { uniqueId } from "shadcn/id"

// Radix's Tabs: roving tabindex across the triggers, arrow keys following the
// orientation, and automatic activation on focus.
export default class extends Controller {
  static targets = [ "trigger", "content" ]
  static values = {
    value: String,
    orientation: { type: String, default: "horizontal" },
    activation: { type: String, default: "automatic" }
  }

  connect() {
    if (!this.valueValue) {
      const first = this.triggerTargets.find((t) => !t.disabled)
      if (first) this.valueValue = first.dataset.value || ""
    }
    this.render()
  }

  select(event) {
    const trigger = event.currentTarget
    if (trigger.disabled) return

    this.valueValue = trigger.dataset.value || ""
    this.render()
    this.dispatch("change", { detail: { value: this.valueValue } })
  }

  keydown(event) {
    const horizontal = this.orientationValue === "horizontal"
    const forward = horizontal ? "ArrowRight" : "ArrowDown"
    const backward = horizontal ? "ArrowLeft" : "ArrowUp"
    // Right-to-left swaps the two horizontal arrows, so the key that *means*
    // forward is translated before it is compared. `shadcn/direction.js` says
    // why this is a module and not a provider.
    const key = directionAwareKey(event.key, readDirection(this.element))

    const triggers = this.triggerTargets.filter((t) => !t.disabled)
    const index = triggers.indexOf(event.currentTarget)
    if (index === -1) return

    let next = null
    if (key === forward) next = triggers[(index + 1) % triggers.length]
    else if (key === backward) next = triggers[(index - 1 + triggers.length) % triggers.length]
    else if (event.key === "Home") next = triggers[0]
    else if (event.key === "End") next = triggers[triggers.length - 1]
    else return

    event.preventDefault()
    next.focus({ preventScroll: true })
    if (this.activationValue === "automatic") next.click()
  }

  render() {
    this.triggerTargets.forEach((trigger) => {
      const value = trigger.dataset.value || ""
      const active = value === this.valueValue
      const panel = this.contentTargets.find((c) => (c.dataset.value || "") === value)

      if (!trigger.id) trigger.id = uniqueId("shadcn-tab")

      trigger.dataset.state = active ? "active" : "inactive"
      trigger.setAttribute("aria-selected", String(active))
      trigger.setAttribute("tabindex", active ? "0" : "-1")

      if (!panel) return
      if (!panel.id) panel.id = uniqueId("shadcn-tabpanel")
      trigger.setAttribute("aria-controls", panel.id)
      panel.setAttribute("aria-labelledby", trigger.id)
    })

    this.contentTargets.forEach((content) => {
      const active = (content.dataset.value || "") === this.valueValue
      content.dataset.state = active ? "active" : "inactive"
      content.hidden = !active
    })
  }
}
