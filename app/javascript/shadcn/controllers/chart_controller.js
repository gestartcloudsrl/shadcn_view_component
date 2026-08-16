import { Controller } from "@hotwired/stimulus"

// The chart is drawn by the server — every mark is already in the document,
// with its label and the value it should show. This is the half a static SVG
// cannot do: move the tooltip, for a pointer and for the arrow keys.
//
// Nothing here computes anything about the data. It reads what the mark
// carries and moves a panel, which is why a chart of a hundred marks costs the
// same as a chart of three.
export default class extends Controller {
  static targets = [ "mark", "tooltip", "label", "name", "value", "indicator" ]

  // Far enough that the tooltip does not sit under the pointer that summoned
  // it, which is what makes it flicker.
  static OFFSET = 12

  static STEPS = { ArrowRight: 1, ArrowDown: 1, ArrowLeft: -1, ArrowUp: -1 }

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
    this.cursor = null
  }

  // The other way to the tooltip, for someone who sees the chart and has no
  // pointer. The graphic carries `role="application"`, which is what keeps a
  // screen reader from taking the arrow keys before they arrive here; the
  // numbers themselves are in the table beside it, so nothing is announced
  // from this — it moves a panel, and that is all it claims to do.
  navigate(event) {
    if (event.key === "Escape") return this.hide()

    const marks = this.markTargets
    const step = this.constructor.STEPS[event.key]
    if (!marks.length) return
    if (step === undefined && !["Home", "End"].includes(event.key)) return

    event.preventDefault()
    this.cursor = this.next(event.key, step, marks.length)

    const mark = marks[this.cursor]
    this.fill(mark)
    this.tooltipTarget.hidden = false
    this.placeOn(mark)
  }

  // Clamped rather than wrapped: an edge you can feel is how you know the
  // series ended, where wrapping reads as a chart that starts over.
  next(key, step, count) {
    if (key === "Home") return 0
    if (key === "End") return count - 1
    if (this.cursor == null) return step > 0 ? 0 : count - 1

    return Math.min(Math.max(this.cursor + step, 0), count - 1)
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

  place(event) {
    this.moveTo(event.clientX, event.clientY)
  }

  // A keyboard has no pointer to follow, so the mark itself is the anchor —
  // the top of the bar, the top of the slice's box.
  placeOn(mark) {
    const box = mark.getBoundingClientRect()

    this.moveTo(box.left + box.width / 2, box.top)
  }

  // Positioned against the container, so a scrolled page or a chart inside a
  // card needs no measuring of its own — and kept inside it, because a tooltip
  // that hangs off the edge is what a caller's `overflow-hidden` clips.
  moveTo(clientX, clientY) {
    const box = this.element.getBoundingClientRect()
    const tooltip = this.tooltipTarget.getBoundingClientRect()
    const offset = this.constructor.OFFSET

    const x = clientX - box.left + offset
    const y = clientY - box.top + offset

    this.tooltipTarget.style.left = `${Math.min(Math.max(0, x), Math.max(0, box.width - tooltip.width))}px`
    this.tooltipTarget.style.top = `${Math.min(Math.max(0, y), Math.max(0, box.height - tooltip.height))}px`
  }
}
