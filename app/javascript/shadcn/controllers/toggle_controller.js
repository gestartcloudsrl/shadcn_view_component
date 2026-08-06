import { Controller } from "@hotwired/stimulus"

// Radix's Toggle: an `aria-pressed` button whose styling keys off
// `data-state="on" | "off"`.
export default class extends Controller {
  static values = { pressed: Boolean, disabled: Boolean }

  connect() {
    this.render()
  }

  toggle() {
    if (this.disabledValue) return

    this.pressedValue = !this.pressedValue
    this.render()
    this.dispatch("change", { detail: { pressed: this.pressedValue } })
  }

  render() {
    this.element.dataset.state = this.pressedValue ? "on" : "off"
    this.element.setAttribute("aria-pressed", String(this.pressedValue))
  }
}
