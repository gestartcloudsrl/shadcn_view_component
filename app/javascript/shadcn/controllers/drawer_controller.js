import { Controller } from "@hotwired/stimulus"

// vaul's own numbers (vaul/src/constants.ts). A release counts as a throw above
// 0.4 px/ms whatever the distance; below that it closes only once a quarter of
// the drawer has been dragged off screen.
const VELOCITY_THRESHOLD = 0.4
const CLOSE_THRESHOLD = 0.25

// After a scroll inside the drawer, a press within this window cannot start a
// drag — otherwise the finish of a flick-scroll drags the drawer away.
const SCROLL_LOCK_TIMEOUT = 100

// A press landing while the drawer is still coming in scrolls rather than drags.
const OPEN_GRACE = 500

// Dragging *into* the drawer has nowhere to go, so it is rubber-banded rather
// than stopped dead (vaul/src/helpers.ts:90-92).
const dampen = (value) => 8 * (Math.log(value + 1) - 2)

const VERTICAL = new Set([ "top", "bottom" ])

// The drag half of vaul's Drawer, which is the only half that is vaul's: the
// rest of this component is Radix's Dialog, and runs on `shadcn--dialog`, whose
// controller this one reaches for when a release means close.
//
// Four things vaul does are deliberately not here — snap points, scaling the
// page behind the drawer, its iOS `position: fixed` workaround, and nested
// drawers. See features/drawer.md for what each would cost and why.
export default class extends Controller {
  static targets = [ "content", "overlay" ]

  connect() {
    this.openedAt = null
    this.scrollPreventedAt = null
    this.reset()

    // The press that opens the drawer arrives before the animation does, and a
    // drag started during it reads a transform that is still moving.
    this.opened = () => { this.openedAt = Date.now() }
    this.element.addEventListener("shadcn--dialog:open", this.opened)
  }

  disconnect() {
    this.element.removeEventListener("shadcn--dialog:open", this.opened)
  }

  get direction() {
    return this.hasContentTarget ? this.contentTarget.dataset.vaulDrawerDirection : "bottom"
  }

  get vertical() {
    return VERTICAL.has(this.direction)
  }

  // Which way is "away". Bottom and right close by growing the coordinate, top
  // and left by shrinking it, so one multiplier covers all four.
  get multiplier() {
    return this.direction === "bottom" || this.direction === "right" ? 1 : -1
  }

  press(event) {
    if (!this.hasContentTarget || event.button !== 0) return

    this.dragging = true
    this.allowed = false
    this.startedAt = Date.now()
    this.start = this.vertical ? event.pageY : event.pageX
    // Capture, which vaul does not do — and the one place this port knowingly
    // adds something rather than leaving something out.
    //
    // A touch pointer is captured by the browser anyway, so on the device this
    // component is designed for vaul already gets every move and every release.
    // A mouse is not, and vaul binds its handlers to the panel, so with a mouse
    // it loses the gesture the moment the cursor crosses the panel's edge —
    // which a drag *upwards* does immediately, since the rubber band leaves the
    // pointer above the panel by design. Both halves of that were reported here
    // from the gallery: a drag that stopped following, and, before it, a drag
    // released outside that never ended at all because the `pointerup` went to
    // whatever was under the cursor.
    //
    // Capturing makes the mouse behave the way touch already does rather than
    // changing what the component does. The one thing it costs is the target,
    // recovered in `elementUnder` below.
    this.contentTarget.setPointerCapture?.(event.pointerId)
  }

  move(event) {
    if (!this.dragging) return


    const moved = (this.start - (this.vertical ? event.pageY : event.pageX)) * this.multiplier
    // Positive is *into* the drawer, which is the direction that scrolls.
    const inward = moved > 0

    if (!this.allowed && !this.shouldDrag(this.elementUnder(event), inward)) return
    this.allowed = true

    this.hold(this.contentTarget)
    this.hold(this.overlayElement)

    if (inward) {
      this.translate(Math.min(dampen(moved) * -1, 0) * this.multiplier)
      return
    }

    const distance = Math.abs(moved)
    this.translate(distance * this.multiplier)
    this.fade(1 - distance / this.size)
  }

  release(event) {
    if (!this.dragging) return

    this.dragging = false
    if (!this.allowed) return
    this.allowed = false

    const moved = this.start - (this.vertical ? event.pageY : event.pageX)
    const elapsed = Date.now() - this.startedAt
    const velocity = elapsed > 0 ? Math.abs(moved) / elapsed : 0
    const away = moved * this.multiplier < 0

    if (!away) return this.reset()
    if (velocity > VELOCITY_THRESHOLD) return this.dismiss()
    if (Math.abs(moved) >= this.size * CLOSE_THRESHOLD) return this.dismiss()

    this.reset()
  }

  // vaul's `shouldDrag`, minus the snap-point branches. It is what keeps a
  // scrollable drawer usable: a press that means "scroll the list" must not
  // also mean "throw the drawer away".
  // What the pointer is really over. Capture retargets every move at the panel,
  // and this is the one thing `shouldDrag` cannot do without: it climbs from
  // there to find the scroller that owns the gesture, and a captured event says
  // "the panel" every time.
  elementUnder(event) {
    return document.elementFromPoint(event.clientX, event.clientY) || event.target
  }

  shouldDrag(target, inward) {
    let element = target

    if (element.tagName === "SELECT") return false
    if (element.closest("[data-vaul-no-drag]")) return false

    // Sideways drawers have no scroll axis to compete with.
    if (!this.vertical) return true

    if (this.openedAt && Date.now() - this.openedAt < OPEN_GRACE) return false

    // Already part-way out: keep dragging whatever is underneath.
    if (this.translated !== 0) return true

    if (window.getSelection()?.toString()) return false

    if (this.scrollPreventedAt && Date.now() - this.scrollPreventedAt < SCROLL_LOCK_TIMEOUT) {
      this.scrollPreventedAt = Date.now()
      return false
    }

    if (inward) {
      this.scrollPreventedAt = Date.now()
      return false
    }

    // Climb to the first scrollable ancestor. One scrolled away from its top
    // owns the gesture; the drawer itself is where the climb stops.
    while (element && element !== this.element) {
      if (element.scrollHeight > element.clientHeight) {
        if (element.scrollTop !== 0) {
          this.scrollPreventedAt = Date.now()
          return false
        }

        if (element.getAttribute("role") === "dialog") return true
      }

      element = element.parentElement
    }

    return true
  }

  // How far the drawer has to travel to be gone, along the axis it moves on.
  get size() {
    const box = this.contentTarget.getBoundingClientRect()

    return this.vertical
      ? Math.min(box.height, window.innerHeight)
      : Math.min(box.width, window.innerWidth)
  }

  // Read back rather than remembered: a `turbo:morph` or a second press can
  // arrive between two drags, and the element is the only thing that knows.
  get translated() {
    const matrix = new DOMMatrixReadOnly(getComputedStyle(this.contentTarget).transform)

    return this.vertical ? matrix.m42 : matrix.m41
  }

  get overlayElement() {
    return this.hasOverlayTarget ? this.overlayTarget : null
  }

  translate(value) {
    this.contentTarget.style.transform = this.vertical
      ? `translate3d(0, ${value}px, 0)`
      : `translate3d(${value}px, 0, 0)`
  }

  fade(opacity) {
    if (this.overlayElement) this.overlayElement.style.opacity = String(opacity)
  }

  // The transition has to be off *while* a finger is on the drawer, or every
  // frame chases the last one and the drawer lags behind the pointer.
  hold(element) {
    if (element) element.style.transition = "none"
  }

  reset() {
    for (const element of [ this.hasContentTarget && this.contentTarget, this.overlayElement ]) {
      if (!element) continue

      element.style.transform = ""
      element.style.opacity = ""
      element.style.transition = ""
    }
  }

  // The inline styles go first, and it is the `transform` that matters rather
  // than the `transition`: nothing clears it on the way out, so the next time
  // the drawer is opened it comes up already pushed however far the last drag
  // pushed it — measured at 60px on the example that covers this, which is the
  // whole of what the throw moved it.
  dismiss() {
    this.reset()
    this.dialog?.close()
  }

  get dialog() {
    return this.application.getControllerForElementAndIdentifier(this.element, "shadcn--dialog")
  }
}
