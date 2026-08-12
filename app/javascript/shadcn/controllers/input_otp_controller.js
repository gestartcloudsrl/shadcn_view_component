import { Controller } from "@hotwired/stimulus"

// The three values `input-otp.tsx` reads per box, and the rule the package
// computes them with (input.tsx:596-618):
//
//   char         value[i], or nothing
//   isActive     focused, and i is where the selection is — the caret's box, or
//                any box inside a range
//   hasFakeCaret active and empty
//
// Everything under them is one real `<input>` lying over the boxes, so the
// browser owns typing, paste, backspace, the arrows and the one-time-code
// autofill, and this owns painting.
export default class extends Controller {
  static targets = [ "input", "slot", "char", "caret" ]
  static values = { length: { type: Number, default: 6 } }

  connect() {
    // The input's font size is the boxes' height, so its (invisible) text lines
    // up with them and a native selection paints where a person would expect.
    // Read rather than assumed: the boxes are sized by classes a caller may
    // change.
    this.element.style.setProperty("--shadcn-input-otp-height", `${this.boxHeight}px`)

    this.refresh()
  }

  get boxHeight() {
    return this.hasSlotTarget ? Math.round(this.slotTargets[0].getBoundingClientRect().height) : 36
  }

  // The caret never sits past the last box. The package clamps the selection on
  // focus and after every change — `min(value.length, maxLength - 1)` to
  // `value.length` (input.tsx:432, 472) — which is what keeps the last box lit
  // when the code is complete instead of leaving none of them lit.
  clamp() {
    const input = this.inputTarget
    const length = input.value.length
    const start = Math.min(length, this.lengthValue - 1)

    if (input.selectionStart !== start || input.selectionEnd !== length) {
      input.setSelectionRange(start, length)
    }
  }

  focus() {
    this.clamp()
    this.refresh()
  }

  // `onComplete` in upstream's API, which has no counterpart in markup: an
  // event, so an app can submit the form or move on without this component
  // deciding which.
  entered() {
    this.clamp()
    this.refresh()

    if (this.inputTarget.value.length === this.lengthValue) {
      this.dispatch("complete", { detail: { value: this.inputTarget.value } })
    }
  }

  refresh() {
    const input = this.inputTarget
    const value = input.value
    const focused = document.activeElement === input
    const start = input.selectionStart
    const end = input.selectionEnd

    this.slotTargets.forEach((slot, index) => {
      const char = value[index]
      const active = focused && start !== null && end !== null &&
        ((start === end && index === start) || (index >= start && index < end))

      slot.dataset.active = String(active)
      if (this.charTargets[index]) this.charTargets[index].textContent = char ?? ""
      if (this.caretTargets[index]) this.caretTargets[index].hidden = !(active && char === undefined)
    })
  }
}
