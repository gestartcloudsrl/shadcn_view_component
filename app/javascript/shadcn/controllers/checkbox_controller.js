import { Controller } from "@hotwired/stimulus"

// Radix's Checkbox: a `role="checkbox"` button plus a hidden native input that
// carries the value into the form. The indicator is mounted only while checked,
// so it is detached rather than hidden.
export default class extends Controller {
  static targets = [ "indicator" ]
  static values = { checked: Boolean, indeterminate: Boolean, disabled: Boolean, inputId: String }

  connect() {
    this.indicator = this.hasIndicatorTarget ? this.indicatorTarget : null
    // Radix renders the hidden input as a *sibling* of the button, so it lives
    // outside this controller's scope and is looked up by id instead.
    this.input = this.inputIdValue ? document.getElementById(this.inputIdValue) : null
    this.render()
  }

  toggle(event) {
    if (this.disabledValue) return
    event?.preventDefault()

    this.indeterminateValue = false
    this.checkedValue = !this.checkedValue
    this.render()
    this.dispatch("change", { detail: { checked: this.checkedValue } })

    if (this.input) this.input.dispatchEvent(new Event("change", { bubbles: true }))
  }

  keydown(event) {
    // Enter must not submit the surrounding form, matching Radix.
    if (event.key === "Enter") event.preventDefault()
  }

  get state() {
    if (this.indeterminateValue) return "indeterminate"
    return this.checkedValue ? "checked" : "unchecked"
  }

  render() {
    const state = this.state

    this.element.dataset.state = state
    this.element.setAttribute(
      "aria-checked",
      state === "indeterminate" ? "mixed" : String(this.checkedValue)
    )

    if (this.input) this.input.checked = this.checkedValue

    if (!this.indicator) return

    if (state === "unchecked") {
      this.indicator.remove()
    } else {
      this.indicator.dataset.state = state
      this.indicator.hidden = false
      if (!this.indicator.isConnected) this.element.appendChild(this.indicator)
    }
  }
}
