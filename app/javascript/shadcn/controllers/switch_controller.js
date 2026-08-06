import { Controller } from "@hotwired/stimulus"

// Radix's Switch: a `role="switch"` button whose thumb is moved by
// `data-state`, plus a hidden checkbox for form submission. As with Checkbox,
// Radix renders that input as a sibling of the button, so it lives outside this
// controller's scope and is resolved by id.
export default class extends Controller {
  static targets = [ "thumb" ]
  static values = { checked: Boolean, disabled: Boolean, inputId: String }

  connect() {
    this.input = this.inputIdValue ? document.getElementById(this.inputIdValue) : null
    this.render()
  }

  toggle(event) {
    if (this.disabledValue) return
    event?.preventDefault()

    this.checkedValue = !this.checkedValue
    this.render()
    this.dispatch("change", { detail: { checked: this.checkedValue } })

    if (this.input) this.input.dispatchEvent(new Event("change", { bubbles: true }))
  }

  keydown(event) {
    if (event.key === "Enter") event.preventDefault()
  }

  render() {
    const state = this.checkedValue ? "checked" : "unchecked"

    this.element.dataset.state = state
    this.element.setAttribute("aria-checked", String(this.checkedValue))
    if (this.hasThumbTarget) this.thumbTarget.dataset.state = state
    if (this.input) this.input.checked = this.checkedValue
  }
}
