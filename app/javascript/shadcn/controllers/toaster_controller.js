import { Controller } from "@hotwired/stimulus"
import { ExitQueue } from "shadcn/animation"

// sonner's own numbers, read from its source: four seconds of life, 200ms to
// leave. The lifetime is a value so a caller can change it; the exit is not,
// because it has to agree with the classes on the toast.
const DEFAULT_DURATION = 4000

// sonner's, read from its source: 14px between toasts.
const GAP = 14

// The toaster is a *list* and this is its clock. Toasts arrive three ways —
// rendered with the page from a flash, appended by a Turbo Stream, or asked for
// in JavaScript — and this treats all three the same: anything that appears in
// the list starts its own timer and leaves when it runs out.
//
// Which is why there is a MutationObserver rather than a method every route has
// to remember to call. A `turbo_stream.append` knows nothing about this
// controller and should not have to.
export default class extends Controller {
  static targets = [ "list", "toast", "template" ]
  static values = { duration: { type: Number, default: DEFAULT_DURATION } }

  connect() {
    this.timers = new Map()
    this.exits = new ExitQueue()
    this.hovering = false
    this.focused = false
    this.expanded = false
    this.floor = 0

    this.watch = new MutationObserver((records) => {
      for (const record of records) {
        for (const node of record.addedNodes) {
          if (node.nodeType === Node.ELEMENT_NODE && node.dataset.slot === "toast") this.start(node)
        }
      }

      this.place()
    })
    this.watch.observe(this.listTarget, { childList: true })

    for (const toast of this.toastElements) this.start(toast)

    // A toast's own height decides where the one behind it sits, and a height
    // changes when the window narrows and a line wraps.
    this.resizes = new ResizeObserver(() => this.place())
    this.resizes.observe(this.listTarget)

    this.place()
  }

  disconnect() {
    this.watch.disconnect()
    this.resizes.disconnect()
    for (const timer of this.timers.values()) clearTimeout(timer)
    this.timers.clear()
    this.exits.flushAll()
  }

  // `document.dispatchEvent(new CustomEvent("shadcn--toast", { detail: … }))`.
  // The detail is the component's own arguments, so the two routes read alike.
  raise(event) {
    const { title, description, variant = "default", duration } = event.detail ?? {}
    // One template per variant: a variant carries an icon or does not, and an
    // element that was never rendered cannot be brought back by an attribute.
    const template = this.templateTargets.find((t) => t.dataset.variant === variant) ||
      this.templateTargets.find((t) => t.dataset.variant === "default")
    if (!template) return

    const toast = template.content.firstElementChild.cloneNode(true)
    // `if (duration)` would drop a 0, which is the one value that means
    // something here: no clock. The same slip twice in one file.
    if (duration !== undefined && duration !== null) toast.dataset.duration = duration
    this.fill(toast, "toast-title", title)
    this.fill(toast, "toast-description", description)

    this.listTarget.appendChild(toast)
  }

  dismiss(event) {
    this.close(event.currentTarget.closest("[data-slot=toast]"))
  }

  // Hovering does two things, and they are the same gesture: it stops every
  // clock, and it opens the stack. On the list rather than on each toast — a
  // pointer crossing from one to another must not restart the others, and must
  // not collapse the stack under itself on the way.
  //
  // A pointer and a keyboard can hold it open at the same time, and they are
  // tracked apart rather than as one flag: a `focusout` while the pointer is
  // still on the stack is not the stack being let go.
  hold(event) {
    if (event?.type === "focusin") this.focused = true
    else this.hovering = true

    this.settle()
  }

  // Only the half the event is about. Closing a toast takes away the button the
  // focus was on, and the browser reports that as focus leaving the stack — so
  // a `focusout` that clears both would shut a stack the pointer is still on,
  // which is what was reported. Focus moving *within* the stack needs nothing
  // here: the `focusin` that follows it arrives in the same tick.
  release(event) {
    if (event?.type === "focusout") this.focused = false
    else this.hovering = false

    this.settle()
  }

  // Open while either a pointer or the keyboard is on it; counting down only
  // once neither is.
  settle() {
    this.expanded = this.hovering || this.focused

    for (const timer of this.timers.values()) clearTimeout(timer)
    this.timers.clear()

    this.place()

    if (this.expanded) return

    for (const toast of this.toastElements) this.start(toast)
  }

  // A toast on its way out is not one of these any more. It keeps the transform
  // it had and fades where it stands, while the ones left take their new places
  // — which is the difference between a stack that scrolls and one that jumps
  // once the element finally goes.
  get toastElements() {
    return [ ...this.listTarget.querySelectorAll("[data-slot=toast]:not([data-state=closed])") ]
  }

  get lift() {
    return this.element.dataset.position?.startsWith("top") ? 1 : -1
  }

  // Where every toast sits, collapsed and expanded, and how tall the box a
  // pointer has to be inside is.
  //
  // sonner's arrangement, read from its stylesheet: collapsed, the newest is at
  // the front at its own height and each one behind it is lifted by a gap,
  // scaled down a twentieth per place, and has its content faded out — so a
  // stack reads as one toast with others behind it. Expanded, each returns to
  // its own height and is lifted past the ones in front of it.
  place() {
    const toasts = this.toastElements
    if (toasts.length === 0) {
      this.floor = 0
      this.listTarget.style.height = "0px"
      this.listTarget.style.pointerEvents = "none"
      return
    }

    // Front first: the newest is nearest the edge, and for a stack anchored at
    // the bottom that is the last one in the list.
    const front = this.lift > 0 ? toasts : [ ...toasts ].reverse()
    const heights = front.map((toast) => this.heightOf(toast))
    const frontHeight = heights[0]
    const edge = this.lift > 0 ? "top" : "bottom"
    let stacked = 0
    let reach = 0

    front.forEach((toast, index) => {
      const behind = index > 0
      const offset = this.expanded ? stacked + GAP * index : GAP * index
      const scale = this.expanded || !behind ? 1 : 1 - index * 0.05
      const height = this.expanded || !behind ? heights[index] : frontHeight

      toast.style.zIndex = String(front.length - index)
      toast.style.transform = `translateY(${this.lift * offset}px) scale(${scale})`
      // Scaled from the edge it is anchored to, not from its middle: a toast
      // scaled about its centre grows *upwards* as well as inwards, and reaches
      // past the box it is meant to be inside.
      toast.style.transformOrigin = `${edge} center`
      toast.style.height = this.expanded || !behind ? "" : `${frontHeight}px`
      toast.style.opacity = behind && index > 2 && !this.expanded ? "0" : "1"
      toast.style[edge] = "0px"

      // Only the front one is readable while the stack is closed; the rest are
      // shapes behind it, which is what makes a stack look like one toast.
      for (const child of toast.children) {
        child.style.opacity = behind && !this.expanded ? "0" : "1"
      }

      stacked += heights[index]
      reach = Math.max(reach, offset + height * scale)
    })

    // The box has to hold every toast, because it is the box a pointer must stay
    // inside for the stack to stay open. Computed from how far the toasts
    // actually reach rather than from a sum that looked right.
    this.listTarget.style.height = `${this.box(Math.round(reach))}px`

    // And while the stack is open the box itself has to take the pointer.
    //
    // The region is `pointer-events: none` so the page underneath stays usable
    // around a toast, and each toast turns them back on for itself — which
    // leaves the gaps *between* toasts as holes. A pointer crossing one
    // hit-tests straight through to the page, leaves the list, and the stack
    // shuts and reopens as it lands on the next one: the flicker that was
    // reported. Closed, the holes are wanted; open, they are the reason the
    // stack keeps closing under the pointer that opened it.
    this.listTarget.style.pointerEvents = this.expanded ? "auto" : "none"
  }

  // How tall the box is, which is not always how far the toasts reach: while the
  // stack is open it may grow and must not shrink.
  //
  // The box is anchored at its edge, so a toast going away pulls the far end in
  // by its own height and a gap — past the pointer that is holding the stack
  // open, if that pointer was on the toast that went. The stack then shuts under
  // the hand that opened it, which is what was reported. It is let back down on
  // the way out, where the pointer has already gone.
  box(reach) {
    if (!this.expanded) {
      this.floor = 0
      return reach
    }

    this.floor = Math.max(this.floor, reach)
    return this.floor
  }

  // Measured with the toast at its own size, and remembered: once it is scaled
  // and clipped to the front one's height, the box no longer knows how tall it
  // wants to be.
  heightOf(toast) {
    if (toast.dataset.height) return Number(toast.dataset.height)

    const height = Math.round(toast.getBoundingClientRect().height)
    if (height > 0) toast.dataset.height = String(height)

    return height
  }

  start(toast) {
    if (this.timers.has(toast)) clearTimeout(this.timers.get(toast))

    // `||` would read a `0` as "not given" and hand back the default, which is
    // the opposite of what 0 means here: no clock at all.
    const asked = toast.dataset.duration
    const duration = asked === undefined || asked === "" ? this.durationValue : Number(asked)
    // A toast that is still loading has no business disappearing on a clock.
    if (toast.dataset.variant === "loading" || duration <= 0) return

    this.timers.set(toast, setTimeout(() => this.close(toast), duration))
  }

  close(toast) {
    if (!toast || toast.dataset.state === "closed") return

    clearTimeout(this.timers.get(toast))
    this.timers.delete(toast)
    toast.dataset.state = "closed"
    // `place()` wrote an inline opacity on every toast, and an inline style
    // beats the class that fades this one out. Handing the property back is what
    // lets `data-[state=closed]:opacity-0` play at all — and the queue below
    // waits on that animation, so without this the toast is gone in the same
    // tick rather than on its way out.
    toast.style.opacity = ""
    // And the rest close the gap it leaves while it fades, rather than after.
    this.place()

    // The element waits on its own animation rather than on a number here, so
    // the exit and the classes that draw it cannot drift apart.
    this.exits.defer(toast, () => {
      toast.remove()
      this.place()
    })
  }

  fill(toast, slot, text) {
    const element = toast.querySelector(`[data-slot=${slot}]`)
    if (!element) return

    if (text) element.textContent = text
    else element.remove()
  }
}
