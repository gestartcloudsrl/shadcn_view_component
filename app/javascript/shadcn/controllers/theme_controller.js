import { Controller } from "@hotwired/stimulus"
import {
  CHANGE_EVENT,
  apply,
  getMode,
  getTheme,
  resolvedMode,
  setMode,
  setTheme,
  toggleMode,
  watchSystem
} from "shadcn/theme"

// Drives the mode and colour-theme switchers. It is the counterpart of
// next-themes' `useTheme()` and shadcn's `useThemeConfig()`.
//
// Put it on an element wrapping the control:
//
//   <div data-controller="shadcn--theme">
//     <button data-action="shadcn--theme#toggle">…</button>
//     <div data-mode="dark" data-action="click->shadcn--theme#setMode">Dark</div>
//   </div>
export default class extends Controller {
  connect() {
    apply()
    watchSystem()

    this.onChange = () => this.render()
    document.addEventListener(CHANGE_EVENT, this.onChange)

    this.render()
  }

  disconnect() {
    document.removeEventListener(CHANGE_EVENT, this.onChange)
  }

  // Reads the mode from the clicked element, e.g. `data-mode="dark"`.
  setMode(event) {
    setMode(event.currentTarget.dataset.mode)
  }

  toggle() {
    toggleMode()
  }

  // Reads the palette from the clicked element's `data-value`, which is what
  // the select and dropdown items already carry.
  setTheme(event) {
    setTheme(event.currentTarget.dataset.value)
  }

  // Reflects the current state onto the element so CSS and assistive tech can
  // see it, and marks the active option in any menu inside.
  render() {
    const mode = getMode()

    this.element.dataset.mode = mode
    this.element.dataset.resolvedMode = resolvedMode()
    this.element.dataset.theme = getTheme()

    this.element.querySelectorAll("[data-mode]").forEach((option) => {
      if (option === this.element) return
      option.dataset.active = String(option.dataset.mode === mode)
    })
  }
}
