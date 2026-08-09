import { Controller } from "@hotwired/stimulus"

// Radix's ScrollArea (vendor/radix/ui/scroll-area.tsx): native scrollbars
// hidden, a drawn one in their place.
//
// The layout is CSS. This computes two numbers per axis — how long the thumb is
// and how far along it sits — and publishes the first as the custom property
// the thumb's width or height reads. That split is Radix's, measured on the
// live demo, and it is why 1,189 lines of TSX come down to this: the scrollbar
// is positioned by a stylesheet, not by script.
//
// Two of Radix's four `type` strategies are here: `hover`, its default, and
// `always`. `scroll` and `auto` are not — see features/scroll-area.md.

// Radix's own, and the comment is Radix's too: "minimum of 18 matches macOS
// minimum" (scroll-area.tsx:1065).
const MIN_THUMB = 18

export default class extends Controller {
  static targets = [ "viewport", "content", "scrollbar", "corner" ]
  static values = {
    type: { type: String, default: "hover" },
    hideDelay: { type: Number, default: 600 }
  }

  connect() {
    if (!this.hasViewportTarget) return

    this.dragging = null
    this.hideTimer = null

    this.onScroll = () => this.render()
    this.viewportTarget.addEventListener("scroll", this.onScroll, { passive: true })

    // Content and viewport both change the numbers, and neither change is an
    // event: a row growing is not a scroll.
    this.resizes = new ResizeObserver(() => this.render())
    this.resizes.observe(this.viewportTarget)
    if (this.hasContentTarget) this.resizes.observe(this.contentTarget)

    this.render()
    if (this.typeValue === "always") this.show()
  }

  disconnect() {
    this.viewportTarget?.removeEventListener("scroll", this.onScroll)
    this.resizes?.disconnect()
    if (this.hideTimer) clearTimeout(this.hideTimer)
    this.endDrag()
  }

  // ------------------------------------------------------------ visibility

  pointerEnter() {
    if (this.typeValue !== "hover") return

    if (this.hideTimer) clearTimeout(this.hideTimer)
    this.show()
  }

  pointerLeave() {
    if (this.typeValue !== "hover" || this.dragging) return

    this.hideTimer = setTimeout(() => this.hide(), this.hideDelayValue)
  }

  show() {
    for (const bar of this.scrollbarTargets) {
      // A bar for an axis with nothing to scroll stays hidden however the
      // pointer moves — showing it would draw a full-length thumb that cannot
      // go anywhere.
      bar.dataset.state = this.overflows(this.axisOf(bar)) ? "visible" : "hidden"
    }
  }

  hide() {
    for (const bar of this.scrollbarTargets) bar.dataset.state = "hidden"
  }

  // --------------------------------------------------------------- geometry

  render() {
    for (const bar of this.scrollbarTargets) this.renderBar(bar)

    if (this.typeValue === "always") this.show()
    else if (this.scrollbarTargets.some((bar) => bar.dataset.state === "visible")) this.show()

    this.renderCorner()
  }

  renderBar(bar) {
    const axis = this.axisOf(bar)
    const sizes = this.sizes(axis, bar)
    const thumb = bar.querySelector("[data-slot=scroll-area-thumb]")

    if (!thumb) return

    const thumbSize = this.thumbSize(sizes)
    const offset = this.thumbOffset(sizes, thumbSize)

    if (axis === "horizontal") {
      bar.style.setProperty("--radix-scroll-area-thumb-width", `${thumbSize}px`)
      thumb.style.width = "var(--radix-scroll-area-thumb-width)"
      thumb.style.transform = `translate3d(${offset}px, 0, 0)`
    } else {
      bar.style.setProperty("--radix-scroll-area-thumb-height", `${thumbSize}px`)
      thumb.style.height = "var(--radix-scroll-area-thumb-height)"
      thumb.style.transform = `translate3d(0, ${offset}px, 0)`
    }
  }

  // Radix's `getThumbSize` (scroll-area.tsx:1061): the track's length times the
  // fraction of the content on screen, never below 18px — past that the thumb
  // stops being a proportion and starts being a handle.
  thumbSize({ viewport, content, track }) {
    const ratio = content > 0 ? viewport / content : 0

    return Math.max(track * ratio, MIN_THUMB)
  }

  // `getThumbOffsetFromScroll` (:1087), which is a linear scale from how far
  // the content has scrolled to how far the thumb can travel.
  thumbOffset({ viewport, content, track, scroll }, thumbSize) {
    const maxScroll = content - viewport
    const maxThumb = track - thumbSize

    if (maxScroll <= 0 || maxThumb <= 0) return 0

    return this.clamp(scroll, 0, maxScroll) * (maxThumb / maxScroll)
  }

  sizes(axis, bar) {
    const viewport = this.viewportTarget
    const horizontal = axis === "horizontal"

    return {
      viewport: horizontal ? viewport.clientWidth : viewport.clientHeight,
      content: horizontal ? viewport.scrollWidth : viewport.scrollHeight,
      scroll: horizontal ? viewport.scrollLeft : viewport.scrollTop,
      // The track is the bar minus its own padding, which is where the 1px of
      // `p-px` goes.
      track: this.trackSize(bar, horizontal)
    }
  }

  trackSize(bar, horizontal) {
    const style = window.getComputedStyle(bar)
    const padding = horizontal
      ? parseFloat(style.paddingLeft) + parseFloat(style.paddingRight)
      : parseFloat(style.paddingTop) + parseFloat(style.paddingBottom)

    return (horizontal ? bar.clientWidth : bar.clientHeight) - (padding || 0)
  }

  overflows(axis) {
    const { viewport, content } = this.sizes(axis, this.scrollbarFor(axis) || this.element)

    return content - viewport > 1
  }

  // The two bars stop short of each other by exactly the other's thickness, and
  // the corner fills what is left. Published as custom properties because that
  // is where the bars' inline `bottom` and `right` already look.
  renderCorner() {
    if (!this.hasCornerTarget) return

    const horizontal = this.scrollbarFor("horizontal")
    const vertical = this.scrollbarFor("vertical")

    this.element.style.setProperty(
      "--radix-scroll-area-corner-width", `${vertical ? vertical.offsetWidth : 0}px`
    )
    this.element.style.setProperty(
      "--radix-scroll-area-corner-height", `${horizontal ? horizontal.offsetHeight : 0}px`
    )
  }

  // ------------------------------------------------------------------ drag

  // On the bar rather than the thumb, so a press on the track jumps there —
  // which is what a native scrollbar does and what Radix's
  // `getScrollPositionFromPointer` computes (:1069).
  startDrag(event) {
    if (event.button !== 0) return

    const bar = event.currentTarget
    const axis = this.axisOf(bar)
    const thumb = bar.querySelector("[data-slot=scroll-area-thumb]")

    event.preventDefault()
    bar.setPointerCapture(event.pointerId)

    const thumbRect = thumb.getBoundingClientRect()
    const pointer = axis === "horizontal" ? event.clientX : event.clientY
    const thumbStart = axis === "horizontal" ? thumbRect.left : thumbRect.top
    const thumbLength = axis === "horizontal" ? thumbRect.width : thumbRect.height
    const inside = pointer >= thumbStart && pointer <= thumbStart + thumbLength

    // Grabbing the thumb keeps the point you took hold of under the pointer;
    // pressing the track centres it on the press instead.
    this.dragging = { bar, axis, grip: inside ? pointer - thumbStart : thumbLength / 2 }

    this.onMove = (moveEvent) => this.drag(moveEvent)
    this.onUp = () => this.endDrag()
    bar.addEventListener("pointermove", this.onMove)
    bar.addEventListener("pointerup", this.onUp)

    this.drag(event)
  }

  drag(event) {
    if (!this.dragging) return

    const { bar, axis, grip } = this.dragging
    const horizontal = axis === "horizontal"
    const sizes = this.sizes(axis, bar)
    const thumbSize = this.thumbSize(sizes)
    const rect = bar.getBoundingClientRect()
    const pointer = (horizontal ? event.clientX - rect.left : event.clientY - rect.top) - grip
    const maxThumb = sizes.track - thumbSize
    const maxScroll = sizes.content - sizes.viewport

    if (maxThumb <= 0 || maxScroll <= 0) return

    const scroll = this.clamp(pointer, 0, maxThumb) * (maxScroll / maxThumb)

    if (horizontal) this.viewportTarget.scrollLeft = scroll
    else this.viewportTarget.scrollTop = scroll
  }

  endDrag() {
    if (!this.dragging) return

    const { bar } = this.dragging
    bar.removeEventListener("pointermove", this.onMove)
    bar.removeEventListener("pointerup", this.onUp)
    this.dragging = null
  }

  // ----------------------------------------------------------------- helpers

  axisOf(bar) {
    return bar.dataset.orientation === "horizontal" ? "horizontal" : "vertical"
  }

  scrollbarFor(axis) {
    return this.scrollbarTargets.find((bar) => this.axisOf(bar) === axis)
  }

  clamp(value, min, max) {
    return Math.min(Math.max(value, min), max)
  }
}
