import { Controller } from "@hotwired/stimulus"

// The one piece of behaviour in an otherwise markup-only family: clicking an
// addon focuses the group's control, so the whole bordered box behaves like the
// input it wraps. A click that landed on a button is left alone — the button is
// what the user meant.
//
// The controller sits on the group rather than on the addon, so `this.element`
// is the group and the lookup matches upstream's
// `currentTarget.parentElement.querySelector("input")`.
export default class extends Controller {
  focusControl(event) {
    if (event.target.closest("button")) return

    this.element.querySelector("input")?.focus()
  }
}
