import { Controller } from "@hotwired/stimulus"

// The chart is drawn by the server — every mark is already in the document,
// with its label and the value it should show. This is the half a static SVG
// cannot do: follow the pointer with the tooltip.
//
// Nothing here computes anything about the data. It reads what the mark
// carries and moves a panel, which is why a chart of a hundred marks costs the
// same as a chart of three.
export default class extends Controller {
  static targets = [ "mark", "tooltip", "label", "name", "value", "indicator" ]

  // Far enough that the tooltip does not sit under the pointer that summoned
  // it, which is what makes it flicker.
  static OFFSET = 12

  show(event) {
    this.fill(event.currentTarget)
    this.tooltipTarget.hidden = false
    this.place(event)
  }

  move(event) {
    if (!this.tooltipTarget.hidden) this.place(event)
  }

  hide() {
    this.tooltipTarget.hidden = true
  }

  // A pie's label and its series name are the same word, so the pie sends one
  // and both cells take it. A bar's are not: the label is the category it
  // stands in and the name is the series it belongs to.
  fill(mark) {
    const { label, name = label, display, key } = mark.dataset

    if (this.hasLabelTarget) this.labelTarget.textContent = label
    if (this.hasNameTarget) this.nameTarget.textContent = name
    if (this.hasValueTarget) this.valueTarget.textContent = display
    // The swatch takes the mark's own fill rather than a colour repeated in
    // JavaScript: `--color-<key>` is published on the container, so the two can
    // never disagree.
    if (this.hasIndicatorTarget) {
      this.indicatorTarget.style.setProperty("--color-bg", `var(--color-${key})`)
      this.indicatorTarget.style.setProperty("--color-border", `var(--color-${key})`)
    }
  }

  // Positioned against the container, so a scrolled page or a chart inside a
  // card needs no measuring of its own — and kept inside it, because a tooltip
  // that hangs off the edge is what a caller's `overflow-hidden` clips.
  place(event) {
    const box = this.element.getBoundingClientRect()
    const tooltip = this.tooltipTarget.getBoundingClientRect()
    const offset = this.constructor.OFFSET

    const x = event.clientX - box.left + offset
    const y = event.clientY - box.top + offset

    this.tooltipTarget.style.left = `${Math.min(Math.max(0, x), Math.max(0, box.width - tooltip.width))}px`
    this.tooltipTarget.style.top = `${Math.min(Math.max(0, y), Math.max(0, box.height - tooltip.height))}px`
  }
}
