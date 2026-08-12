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

    this.alignSnapPoints()

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

  // A slide begins where its *content* begins, and `scroll-snap-align: start`
  // aligns a box. The track carries a negative margin against each item's
  // padding — upstream's gutter, `-ml-4` against `pl-4` — so an item's box
  // starts a gutter before what it holds, and snapping the box to the window
  // pushes a gutter of the card past the far edge. One border's worth, which is
  // how this was reported twice.
  //
  // A negative `scroll-margin` moves each item's snap area onto its content.
  // Read from the item rather than fixed at `1rem`, because the gutter is the
  // caller's: upstream's "Spacing" example halves it.
  alignSnapPoints() {
    for (const item of this.items) {
      const style = getComputedStyle(item)
      const gutter = parseFloat(this.vertical ? style.paddingTop : style.paddingLeft) || 0

      item.style[this.vertical ? "scrollMarginTop" : "scrollMarginLeft"] = `${-gutter}px`
    }
  }

  // Which slide is at the window's start. Asked of the page rather than worked
  // out: every version of this that did arithmetic got it wrong — once by a
  // gutter, once by landing between the browser's own snap points — and the
  // page always knows.
  get leadingIndex() {
    const box = this.viewportTarget.getBoundingClientRect()
    const start = this.vertical ? box.top : box.left
    const distances = this.items.map((item) => {
      const rect = item.getBoundingClientRect()

      return Math.abs((this.vertical ? rect.top : rect.left) - start)
    })

    return distances.indexOf(Math.min(...distances))
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

  // The slide next to the one in front, placed by the browser rather than by a
  // number of this controller's own. `scrollIntoView` uses the same alignment a
  // released drag settles on, so a finger and a button cannot disagree.
  //
  // `nearest` on the other axis so the page does not move under a horizontal
  // carousel. No `behavior`: `scroll-behavior` is declared in CSS under a
  // reduced-motion guard, and a context that has decided not to animate can
  // leave a `behavior: "smooth"` scroll unstarted rather than instant.
  go(direction) {
    const item = this.items[this.leadingIndex + direction]
    if (!item) return

    item.scrollIntoView(this.vertical
      ? { block: "start", inline: "nearest" }
      : { inline: "start", block: "nearest" })
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
