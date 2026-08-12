import { Controller } from "@hotwired/stimulus"
import { directionAwareKey, readDirection } from "shadcn/direction"

// The six things `carousel.tsx` asks embla for — `scrollPrev`, `scrollNext`,
// `canScrollPrev`, `canScrollNext`, and the `select`/`reInit` events — asked of
// a scroll container instead. The viewport snaps, so the browser owns the
// dragging, the momentum and where a release lands; this reads one number to
// answer the two questions and writes one to move.
//
// What that leaves out is real and is in features/carousel.md: no `loop`, no
// `align`, no `slidesToScroll`, no plugins, and no mouse-drag — a finger drags
// a scroller, a cursor does not, and embla implements that itself.
export default class extends Controller {
  static targets = [ "viewport", "previous", "next" ]
  static values = { orientation: { type: String, default: "horizontal" } }

  connect() {
    this.update = this.update.bind(this)
    this.viewportTarget.addEventListener("scroll", this.update, { passive: true })

    // A slide is as wide as the viewport until a caller says otherwise, so both
    // answers change when the box does.
    this.resizes = new ResizeObserver(this.update)
    this.resizes.observe(this.viewportTarget)

    this.update()
  }

  disconnect() {
    this.viewportTarget.removeEventListener("scroll", this.update)
    this.resizes.disconnect()
  }

  get vertical() {
    return this.orientationValue === "vertical"
  }

  get position() {
    return this.vertical ? this.viewportTarget.scrollTop : this.viewportTarget.scrollLeft
  }

  get extent() {
    const el = this.viewportTarget

    return this.vertical ? el.scrollHeight - el.clientHeight : el.scrollWidth - el.clientWidth
  }

  get items() {
    return [ ...this.viewportTarget.querySelectorAll("[data-slot=carousel-item]") ]
  }

  // Measured rather than counted in widths, and **relative to the first slide**.
  //
  // That is the whole of the fix for a reported defect, and the reason is worth
  // keeping. The track carries a negative margin against each item's padding —
  // upstream's gutter, `-ml-4` against `pl-4` — so an item is a gutter wider
  // than the window, and its box begins a gutter left of the scroller's zero.
  // Taken from the viewport's edge, the numbers are a gutter short: scrolling to
  // one lines an item's *box* up with the window and pushes a gutter of its
  // *content* off the far side. A card loses its border that way, and nothing
  // that reads attributes can tell.
  //
  // Relative to the first item they are what the browser itself uses: the
  // scroll origin is the track's start, so `scroll-snap-align: start` already
  // agrees with these, and a released drag lands where a button would. An
  // earlier version set a negative `scroll-margin` on every item to make that
  // true; measured, it already was, and no mutation could tell the difference.
  get offsets() {
    const box = this.viewportTarget.getBoundingClientRect()
    const start = this.vertical ? box.top : box.left
    const positions = this.items.map((item) => {
      const rect = item.getBoundingClientRect()

      return (this.vertical ? rect.top : rect.left) - start + this.position
    })

    const first = positions[0] ?? 0

    return positions.map((position) => Math.round(position - first))
  }

  previous() {
    this.go(-1)
  }

  next() {
    this.go(1)
  }

  keydown(event) {
    const key = directionAwareKey(event.key, readDirection(this.element))

    if (key === "ArrowLeft") {
      event.preventDefault()
      this.previous()
    } else if (key === "ArrowRight") {
      event.preventDefault()
      this.next()
    }
  }

  // The nearest slide past where we are, in the direction asked for. A pixel of
  // slack because a settled scroll is rarely a whole number.
  go(direction) {
    const at = this.position
    const offsets = this.offsets
    const candidates = direction > 0
      ? offsets.filter((offset) => offset > at + 1)
      : offsets.filter((offset) => offset < at - 1).reverse()

    const to = candidates[0]
    if (to === undefined) return

    // No `behavior` here. `scroll-behavior` is in the stylesheet, under a
    // `prefers-reduced-motion` guard, so the browser decides whether to animate
    // and this asks only for a destination. Passing `behavior: "smooth"` would
    // take that decision away from it — and in a context that runs no animation
    // frames the scroll then never starts at all, which is a carousel that does
    // nothing rather than one that jumps.
    this.viewportTarget.scrollTo({ [this.vertical ? "top" : "left"]: to })
  }

  // A pixel of slack at each end: a smooth scroll settles on a fractional
  // position often enough that an exact comparison leaves the button that just
  // worked looking broken.
  update() {
    const at = this.position

    this.toggle(this.hasPreviousTarget && this.previousTarget, at > 1)
    this.toggle(this.hasNextTarget && this.nextTarget, at < this.extent - 1)
  }

  toggle(button, enabled) {
    if (button) button.disabled = !enabled
  }
}
