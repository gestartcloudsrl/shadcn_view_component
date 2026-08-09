import { Controller } from "@hotwired/stimulus"
import { directionAwareKey, readDirection } from "shadcn/direction"

// Radix's ToggleGroup, in both `single` and `multiple` modes, with the roving
// tabindex its items use.
export default class extends Controller {
  static targets = [ "item", "input" ]
  static values = { type: { type: String, default: "single" }, value: String }

  connect() {
    this.render()
  }

  get multiple() {
    return this.typeValue === "multiple"
  }

  get selected() {
    if (!this.valueValue) return []
    return this.valueValue.split(",").filter(Boolean)
  }

  set selected(values) {
    this.valueValue = values.join(",")
  }

  toggle(event) {
    const item = event.currentTarget
    if (item.disabled) return

    const value = item.dataset.value || ""
    const current = this.selected

    if (this.multiple) {
      this.selected = current.includes(value)
        ? current.filter((v) => v !== value)
        : current.concat(value)
    } else {
      this.selected = current.includes(value) ? [] : [ value ]
    }

    this.render()
    this.dispatch("change", { detail: { value: this.valueValue } })
  }

  keydown(event) {
    const key = directionAwareKey(event.key, readDirection(this.element))
    const step = { ArrowRight: 1, ArrowDown: 1, ArrowLeft: -1, ArrowUp: -1 }[key]
    if (!step) return

    event.preventDefault()

    const items = this.itemTargets.filter((item) => !item.disabled)
    if (items.length === 0) return

    const current = items.indexOf(event.currentTarget)
    items[(current + step + items.length) % items.length].focus({ preventScroll: true })
  }

  render() {
    const selected = this.selected
    const enabled = this.itemTargets.filter((item) => !item.disabled)

    this.itemTargets.forEach((item) => {
      const on = selected.includes(item.dataset.value || "")
      item.dataset.state = on ? "on" : "off"
      item.setAttribute("aria-pressed", String(on))
      item.setAttribute("tabindex", item === (enabled.find((i) => selected.includes(i.dataset.value)) || enabled[0]) ? "0" : "-1")
    })

    if (this.hasInputTarget) this.inputTarget.value = this.valueValue
  }
}
