import { Controller } from "@hotwired/stimulus"
import { uniqueId } from "shadcn/id"

// Radix's Accordion in `single` and `multiple` modes.
//
// `--radix-accordion-content-height` is what the `animate-accordion-down` /
// `animate-accordion-up` keyframes interpolate to, so it has to be published
// before the state flips.
export default class extends Controller {
  static targets = [ "item", "trigger", "content" ]
  static values = {
    type: { type: String, default: "single" },
    collapsible: Boolean,
    value: String,
    disabled: Boolean
  }

  connect() {
    this.render()
  }

  get multiple() {
    return this.typeValue === "multiple"
  }

  get openValues() {
    return this.valueValue ? this.valueValue.split(",").filter(Boolean) : []
  }

  set openValues(values) {
    this.valueValue = values.join(",")
  }

  toggle(event) {
    const trigger = event.currentTarget
    const item = trigger.closest("[data-slot='accordion-item']")
    if (!item || item.dataset.disabled !== undefined || this.disabledValue) return

    const value = item.dataset.value || ""
    const open = this.openValues

    if (this.multiple) {
      this.openValues = open.includes(value)
        ? open.filter((v) => v !== value)
        : open.concat(value)
    } else if (open.includes(value)) {
      this.openValues = this.collapsibleValue ? [] : open
    } else {
      this.openValues = [ value ]
    }

    this.render()
    this.dispatch("change", { detail: { value: this.valueValue } })
  }

  keydown(event) {
    const triggers = this.triggerTargets.filter((t) => !t.disabled)
    const index = triggers.indexOf(event.currentTarget)
    if (index === -1) return

    let next = null
    switch (event.key) {
      case "ArrowDown": next = triggers[(index + 1) % triggers.length]; break
      case "ArrowUp": next = triggers[(index - 1 + triggers.length) % triggers.length]; break
      case "Home": next = triggers[0]; break
      case "End": next = triggers[triggers.length - 1]; break
      default: return
    }

    event.preventDefault()
    next.focus({ preventScroll: true })
  }

  render() {
    const open = this.openValues

    this.itemTargets.forEach((item) => {
      const isOpen = open.includes(item.dataset.value || "")
      const state = isOpen ? "open" : "closed"
      const trigger = item.querySelector("[data-slot='accordion-trigger']")
      const content = item.querySelector("[data-slot='accordion-content']")

      item.dataset.state = state

      // Radix links trigger and panel by id; do the same once on first render.
      if (trigger && !trigger.id) trigger.id = uniqueId("shadcn-accordion-trigger")
      if (content && !content.id) content.id = uniqueId("shadcn-accordion-content")

      if (trigger) {
        trigger.dataset.state = state
        trigger.setAttribute("aria-expanded", String(isOpen))
        if (content) trigger.setAttribute("aria-controls", content.id)
        const header = trigger.parentElement
        if (header) header.dataset.state = state
      }

      if (!content) return

      if (trigger) content.setAttribute("aria-labelledby", trigger.id)
      content.dataset.state = state

      if (isOpen) {
        content.hidden = false
        content.style.setProperty(
          "--radix-accordion-content-height",
          `${content.scrollHeight}px`
        )
      } else {
        content.hidden = true
      }
    })
  }
}
