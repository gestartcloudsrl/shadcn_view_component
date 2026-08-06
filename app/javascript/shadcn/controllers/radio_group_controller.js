import { Controller } from "@hotwired/stimulus"

// Radix's RadioGroup: `role="radiogroup"` with roving tabindex over its items
// and arrow-key navigation that also selects, per the ARIA radio pattern.
export default class extends Controller {
  static targets = [ "item", "input" ]
  static values = { value: String, disabled: Boolean }

  connect() {
    this.render()
  }

  select(event) {
    const item = event.currentTarget
    if (item.disabled || this.disabledValue) return

    this.valueValue = item.dataset.value || ""
    this.render()
    item.focus({ preventScroll: true })
    this.dispatch("change", { detail: { value: this.valueValue } })

    if (this.hasInputTarget) {
      this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }
  }

  keydown(event) {
    const keys = {
      ArrowDown: 1, ArrowRight: 1, ArrowUp: -1, ArrowLeft: -1
    }
    const step = keys[event.key]
    if (!step) return

    event.preventDefault()

    const items = this.enabledItems
    if (items.length === 0) return

    const current = items.indexOf(event.currentTarget)
    const next = items[(current + step + items.length) % items.length]
    next.click()
  }

  get enabledItems() {
    return this.itemTargets.filter((item) => !item.disabled)
  }

  render() {
    const items = this.itemTargets
    const selected = items.find((item) => item.dataset.value === this.valueValue)

    items.forEach((item) => {
      const checked = item === selected
      item.dataset.state = checked ? "checked" : "unchecked"
      item.setAttribute("aria-checked", String(checked))
      // Roving tabindex: only the selected item (or the first one) is tabbable.
      const tabbable = selected ? checked : item === this.enabledItems[0]
      item.setAttribute("tabindex", tabbable ? "0" : "-1")

      const indicator = item.querySelector("[data-slot='radio-group-indicator']")
      if (!indicator) return
      indicator.hidden = !checked
      indicator.dataset.state = checked ? "checked" : "unchecked"
    })

    if (this.hasInputTarget) this.inputTarget.value = this.valueValue
  }
}
