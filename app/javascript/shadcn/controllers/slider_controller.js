import { Controller } from "@hotwired/stimulus"
import { readDirection } from "shadcn/direction"

// Radix's Slider (vendor/radix/ui/slider.tsx).
//
// The values live in the DOM: each thumb's `aria-valuenow` is the value, and
// everything else — the range's two edges, the wrappers' offsets, the hidden
// inputs — is derived from them. There is no separate model to keep in step,
// which is what a server-rendered slider needs: the markup arrives correct and
// the controller only has to keep it that way.
export default class extends Controller {
  static targets = [ "thumb", "wrapper", "range", "input" ]
  static values = {
    min: { type: Number, default: 0 },
    max: { type: Number, default: 100 },
    step: { type: Number, default: 1 },
    orientation: { type: String, default: "horizontal" },
    disabled: { type: Boolean, default: false },
    // Radix's `minStepsBetweenThumbs` (slider.tsx:121): how close two thumbs
    // may come, counted in steps rather than in value, so it means the same at
    // any scale.
    minSteps: { type: Number, default: 0 }
  }

  connect() {
    this.dragging = null
    this.render()
  }

  disconnect() {
    this.endDrag()
  }

  // ------------------------------------------------------------- reading

  get vertical() { return this.orientationValue === "vertical" }

  get values() {
    return this.thumbTargets.map((thumb) => Number(thumb.getAttribute("aria-valuenow")))
  }

  percentOf(value) {
    if (this.maxValue === this.minValue) return 0

    return this.clamp((value - this.minValue) / (this.maxValue - this.minValue) * 100, 0, 100)
  }

  // ------------------------------------------------------------- writing

  setValue(index, value) {
    const thumb = this.thumbTargets[index]
    if (!thumb) return

    const next = this.constrain(index, value)
    if (next === this.values[index]) return

    thumb.setAttribute("aria-valuenow", String(next))
    this.render()
    this.dispatch("change", { detail: { values: this.values } })
  }

  // Snap to the step, keep inside the ends, and stay clear of the neighbouring
  // thumbs by `minSteps` — Radix's three constraints, applied in that order
  // because a value snapped after clamping can land outside again.
  constrain(index, value) {
    const stepped = this.minValue + Math.round((value - this.minValue) / this.stepValue) * this.stepValue
    const gap = this.minStepsValue * this.stepValue
    const values = this.values
    const lower = index > 0 ? values[index - 1] + gap : this.minValue
    const upper = index < values.length - 1 ? values[index + 1] - gap : this.maxValue

    return this.clamp(Number(stepped.toFixed(10)), Math.max(lower, this.minValue), Math.min(upper, this.maxValue))
  }

  render() {
    const values = this.values
    const edgeStart = this.vertical ? "bottom" : "left"
    const edgeEnd = this.vertical ? "top" : "right"

    if (this.hasRangeTarget) {
      this.rangeTarget.style[edgeStart] = `${this.percentOf(Math.min(...values))}%`
      this.rangeTarget.style[edgeEnd] = `${100 - this.percentOf(Math.max(...values))}%`
    }

    this.wrapperTargets.forEach((wrapper, index) => {
      const percent = this.percentOf(values[index])

      wrapper.style[edgeStart] = `calc(${percent}% + ${this.boundsOffset(index, percent)}px)`
    })

    this.inputTargets.forEach((input, index) => { input.value = String(values[index]) })
  }

  // Radix's `getThumbInBoundsOffset` (slider.tsx:908). The thumb is centred on
  // its value, so at 0% half of it would hang off the start and at 100% off the
  // end. This slides the correction from +half to −half across the track, which
  // keeps the whole thumb inside without moving it anywhere in the middle.
  boundsOffset(index, percent) {
    const thumb = this.thumbTargets[index]
    if (!thumb) return 0

    const size = this.vertical ? thumb.offsetHeight : thumb.offsetWidth
    const half = size / 2

    return half - (percent / 50) * half
  }

  // ------------------------------------------------------------ keyboard

  keydown(event) {
    if (this.disabledValue) return

    const index = this.thumbTargets.indexOf(event.currentTarget)
    if (index === -1) return

    const value = this.values[index]
    // Page keys and Shift+arrow move ten steps, which is Radix's multiplier
    // (slider.tsx:263-264) rather than a number chosen here.
    const large = event.shiftKey || event.key.startsWith("Page")
    const amount = this.stepValue * (large ? 10 : 1)
    const step = this.stepFor(event.key)

    if (step === null) return

    event.preventDefault()

    if (step === "min") return this.setValue(index, this.minValue)
    if (step === "max") return this.setValue(index, this.maxValue)

    this.setValue(index, value + step * amount)
  }

  // Which way a key means "more". In a vertical slider up is more; in a
  // horizontal one that is right, and right-to-left swaps the two arrows —
  // which `shadcn/direction.js` already answers for the whole gem.
  stepFor(key) {
    const rtl = readDirection(this.element) === "rtl"

    switch (key) {
      case "Home": return "min"
      case "End": return "max"
      case "ArrowUp": case "PageUp": return 1
      case "ArrowDown": case "PageDown": return -1
      case "ArrowRight": return rtl ? -1 : 1
      case "ArrowLeft": return rtl ? 1 : -1
      default: return null
    }
  }

  // --------------------------------------------------------------- pointer

  // A press anywhere on the slider moves the nearest thumb to it and starts a
  // drag, which is what makes the whole track a control rather than just the
  // handle.
  trackDown(event) {
    if (this.disabledValue || event.button !== 0) return

    const value = this.valueAtPointer(event)
    const index = this.nearestThumb(value)

    this.beginDrag(event, index)
    this.setValue(index, value)
  }

  thumbDown(event) {
    if (this.disabledValue || event.button !== 0) return

    // The track handler would otherwise run too and re-pick the nearest thumb,
    // which is the wrong one whenever two sit on the same value.
    event.stopPropagation()
    this.beginDrag(event, this.thumbTargets.indexOf(event.currentTarget))
  }

  beginDrag(event, index) {
    event.preventDefault()
    this.thumbTargets[index]?.focus()

    this.dragging = index
    this.onMove = (moveEvent) => this.setValue(this.dragging, this.valueAtPointer(moveEvent))
    this.onUp = () => this.endDrag()

    window.addEventListener("pointermove", this.onMove)
    window.addEventListener("pointerup", this.onUp)
  }

  endDrag() {
    if (this.dragging === null) return

    window.removeEventListener("pointermove", this.onMove)
    window.removeEventListener("pointerup", this.onUp)
    this.dragging = null
  }

  valueAtPointer(event) {
    const rect = this.element.getBoundingClientRect()
    const rtl = readDirection(this.element) === "rtl"
    let fraction

    if (this.vertical) {
      fraction = (rect.bottom - event.clientY) / rect.height
    } else {
      fraction = (event.clientX - rect.left) / rect.width
      if (rtl) fraction = 1 - fraction
    }

    return this.minValue + this.clamp(fraction, 0, 1) * (this.maxValue - this.minValue)
  }

  // Ties go to the lower index, which matters only when two thumbs share a
  // value — and then either choice is arbitrary until one of them moves.
  nearestThumb(value) {
    const values = this.values
    let best = 0

    values.forEach((current, index) => {
      if (Math.abs(current - value) < Math.abs(values[best] - value)) best = index
    })

    return best
  }

  clamp(value, min, max) {
    return Math.min(Math.max(value, min), max)
  }
}
