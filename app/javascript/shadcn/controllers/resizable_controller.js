import { Controller } from "@hotwired/stimulus"

// Panels are shares of a flex container, so the layout is the browser's: this
// only moves two numbers when a handle is dragged, and the browser lays the
// group out again.
//
// The reference is `react-resizable-panels`, 2,252 lines — most of which is
// state, persistence and conditional panels. The arithmetic underneath is a
// delta in pixels turned into a percentage of the group.
export default class extends Controller {
  static targets = [ "panel", "handle" ]
  static values = { orientation: { type: String, default: "horizontal" } }

  // The package's own step for the arrow keys, and its own answer for Home and
  // End: push the separator all the way (`react-resizable-panels.js`, the
  // keydown switch).
  static STEP = 5
  static ALL = 100

  connect() {
    this.publish()
  }

  press(event) {
    const handle = event.currentTarget
    if (handle.getAttribute("aria-disabled") === "true") return

    event.preventDefault()
    handle.setPointerCapture(event.pointerId)
    handle.dataset.separator = "active"

    this.drag = {
      handle,
      from: this.positionOf(event),
      sizes: this.neighbours(handle).map((panel) => this.shareOf(panel))
    }

    this.onMove = (moved) => this.move(moved)
    this.onUp = () => this.release()
    handle.addEventListener("pointermove", this.onMove)
    handle.addEventListener("pointerup", this.onUp)
    handle.addEventListener("pointercancel", this.onUp)
  }

  move(event) {
    if (!this.drag) return

    // In percent, because that is what a share is. The group's own size is the
    // whole, so a drag of 40px in a 400px group is ten points.
    const travelled = (this.positionOf(event) - this.drag.from) / this.extent * 100

    this.resize(this.drag.handle, travelled, this.drag.sizes)
  }

  release() {
    if (!this.drag) return

    const { handle } = this.drag
    handle.removeEventListener("pointermove", this.onMove)
    handle.removeEventListener("pointerup", this.onUp)
    handle.removeEventListener("pointercancel", this.onUp)
    handle.dataset.separator = "inactive"
    this.drag = null
  }

  // The separator pattern: the arrows that lie along the group's own axis move
  // it, and the ones across it do nothing — which is why the orientation is a
  // value rather than something read from the class.
  keydown(event) {
    const handle = event.currentTarget
    if (handle.getAttribute("aria-disabled") === "true") return

    const horizontal = this.orientationValue === "horizontal"
    const steps = {
      ArrowLeft: horizontal ? -this.constructor.STEP : 0,
      ArrowRight: horizontal ? this.constructor.STEP : 0,
      ArrowUp: horizontal ? 0 : -this.constructor.STEP,
      ArrowDown: horizontal ? 0 : this.constructor.STEP,
      Home: -this.constructor.ALL,
      End: this.constructor.ALL
    }
    const step = steps[event.key]
    if (!step) return

    event.preventDefault()
    this.resize(handle, step, this.neighbours(handle).map((panel) => this.shareOf(panel)))
  }

  // Two panels and one number: what one gives the other takes, so the group
  // always adds up to what it added up to before.
  resize(handle, delta, [ before, after ]) {
    const [ first, second ] = this.neighbours(handle)
    if (!first || !second) return

    const total = before + after
    const wanted = before + delta
    const size = Math.min(
      Math.max(wanted, this.limits(first).min, total - this.limits(second).max),
      this.limits(first).max,
      total - this.limits(second).min
    )

    first.style.flexGrow = String(this.round(size))
    second.style.flexGrow = String(this.round(total - size))
    this.publish()
    this.dispatch("resize", { detail: { sizes: this.panelTargets.map((panel) => this.shareOf(panel)) } })
  }

  // `aria-valuenow` is the share of the panel a separator controls, and it is
  // written from here rather than rendered: the server would have to know how
  // many panels the caller put in the block, and it does not.
  publish() {
    for (const handle of this.handleTargets) {
      const [ first ] = this.neighbours(handle)
      if (!first) continue

      handle.setAttribute("aria-controls", first.id)
      handle.setAttribute("aria-valuenow", String(Math.round(this.shareOf(first))))
      handle.setAttribute("aria-valuemin", String(this.limits(first).min))
      handle.setAttribute("aria-valuemax", String(this.limits(first).max))
    }
  }

  // The panels either side of a handle, in DOM order — which is what "either
  // side" means in a flex row that may also be a column.
  neighbours(handle) {
    const parts = [ ...this.element.children ]
    const at = parts.indexOf(handle)

    return [ parts[at - 1], parts[at + 1] ].map((part) => (part?.matches("[data-shadcn--resizable-target=panel]") ? part : null))
  }

  limits(panel) {
    return {
      min: Number(panel.dataset.minSize ?? 0),
      max: Number(panel.dataset.maxSize ?? 100)
    }
  }

  // A share read from the layout rather than from the style, so a group whose
  // panels were never given sizes still has numbers to move: `flex-grow: 1`
  // each renders as equal shares, and this is what they are.
  shareOf(panel) {
    const sizes = this.panelTargets.map((each) => this.lengthOf(each))
    const total = sizes.reduce((sum, size) => sum + size, 0)

    return total ? this.lengthOf(panel) / total * 100 : 0
  }

  lengthOf(element) {
    const box = element.getBoundingClientRect()

    return this.orientationValue === "horizontal" ? box.width : box.height
  }

  get extent() {
    return this.lengthOf(this.element) || 1
  }

  positionOf(event) {
    return this.orientationValue === "horizontal" ? event.clientX : event.clientY
  }

  round(value) {
    return Math.round(value * 100) / 100
  }
}
