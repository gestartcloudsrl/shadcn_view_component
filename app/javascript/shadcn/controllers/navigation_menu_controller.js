import { Controller } from "@hotwired/stimulus"
import { pushLayer, removeLayer } from "shadcn/dismiss"
import { directionAwareKey, readDirection } from "shadcn/direction"

// Radix's NavigationMenu (vendor/radix/ui/navigation-menu.tsx), in the
// `viewport={false}` configuration — see the root component for why that is the
// only one this gem can reproduce.
//
// One panel is open at a time and it belongs to a trigger. Everything else here
// is about *when*: a menu that opened the instant a pointer crossed it would
// flash panels at anyone sweeping past, and one that always waited would feel
// stuck once you were already inside it.
export default class extends Controller {
  static targets = [ "trigger", "content", "indicator" ]
  static values = {
    // Radix's own (navigation-menu.tsx:136-137).
    delay: { type: Number, default: 200 },
    skipDelay: { type: Number, default: 300 }
  }

  connect() {
    this.open = null
    this.timer = null
    this.skipTimer = null
    // True for `skipDelay` after a panel closes: while it is, the next trigger
    // opens with no wait at all. Sweeping across the row should feel like one
    // gesture, not like several.
    this.skipping = false
  }

  disconnect() {
    this.cancel()
    if (this.skipTimer) clearTimeout(this.skipTimer)
    if (this.layer) removeLayer(this.layer)
  }

  // ------------------------------------------------------------- pointing

  pointerEnter(event) {
    if (event.pointerType === "touch") return

    this.cancel()

    const trigger = this.triggerFor(event.currentTarget)
    if (!trigger || trigger === this.open) return

    const wait = this.skipping || this.open ? 0 : this.delayValue
    this.timer = setTimeout(() => this.show(trigger), wait)
  }

  // Leaving anywhere starts a close the next enter can cancel — which is what
  // lets the pointer cross the gap between a trigger and its panel.
  pointerLeave(event) {
    if (event.pointerType === "touch") return

    this.cancel()
    this.timer = setTimeout(() => this.close(), this.delayValue)
  }

  // A tap has no hover to work with, so it toggles.
  toggle(event) {
    const trigger = this.triggerFor(event.currentTarget)
    if (!trigger) return

    event.preventDefault()
    this.cancel()

    if (trigger === this.open) this.close({ focusTrigger: true })
    else this.show(trigger)
  }

  // ------------------------------------------------------------- keyboard

  keydown(event) {
    const key = directionAwareKey(event.key, readDirection(this.element))
    const triggers = this.triggerTargets
    const index = triggers.indexOf(event.currentTarget)

    switch (key) {
      case "ArrowRight":
        event.preventDefault()
        triggers[(index + 1) % triggers.length].focus()
        return
      case "ArrowLeft":
        event.preventDefault()
        triggers[(index - 1 + triggers.length) % triggers.length].focus()
        return
      case "Home":
        event.preventDefault()
        triggers[0].focus()
        return
      case "End":
        event.preventDefault()
        triggers[triggers.length - 1].focus()
        return
      // Down opens and steps into the panel, which is the only way a keyboard
      // reaches the links: the panel is not in the tab order behind its
      // trigger, it is under it.
      case "ArrowDown":
        event.preventDefault()
        this.show(event.currentTarget)
        this.focusFirstLink(event.currentTarget)
    }
  }

  focusFirstLink(trigger) {
    const link = this.contentFor(trigger)?.querySelector("[data-slot=navigation-menu-link]")

    link?.focus()
  }

  // -------------------------------------------------------------- opening

  show(trigger) {
    if (trigger === this.open) return

    const previous = this.open

    this.hideContent(previous, this.motionBetween(previous, trigger, "to"))
    this.open = trigger

    trigger.dataset.state = "open"
    trigger.setAttribute("aria-expanded", "true")

    const content = this.contentFor(trigger)
    if (content) {
      content.dataset.motion = this.motionBetween(previous, trigger, "from")
      content.hidden = false
      content.dataset.state = "open"
    }

    this.moveIndicator(trigger)

    if (this.layer) removeLayer(this.layer)
    this.layer = pushLayer({
      element: content || trigger,
      anchors: this.triggerTargets,
      // Escape and an outside click both arrive here, and only one of them
      // should move focus: dismissing with a key leaves you where the keyboard
      // can carry on, dismissing with a pointer leaves you where you clicked.
      // Handled in the layer rather than in a listener of this controller's,
      // because `dismiss.js` answers Escape first and a second path would find
      // the menu already closed.
      onDismiss: ({ reason }) => this.close({ focusTrigger: reason === "escape" })
    })
  }

  close({ focusTrigger = false } = {}) {
    const trigger = this.open
    if (!trigger) return

    this.hideContent(trigger, null)
    this.open = null

    if (this.layer) removeLayer(this.layer)
    this.layer = null

    if (this.hasIndicatorTarget) {
      this.indicatorTarget.dataset.state = "hidden"
      this.indicatorTarget.hidden = true
    }

    if (focusTrigger) trigger.focus()

    // The grace period. Anything entered inside it opens at once.
    this.skipping = true
    if (this.skipTimer) clearTimeout(this.skipTimer)
    this.skipTimer = setTimeout(() => { this.skipping = false }, this.skipDelayValue)
  }

  hideContent(trigger, motion) {
    if (!trigger) return

    trigger.dataset.state = "closed"
    trigger.setAttribute("aria-expanded", "false")

    const content = this.contentFor(trigger)
    if (!content) return

    if (motion) content.dataset.motion = motion
    content.dataset.state = "closed"
    content.hidden = true
  }

  // Which side the panel comes from, so the pair slides rather than swapping.
  // `null` when there is nothing to come from — a first open is not a move.
  motionBetween(previous, next, prefix) {
    if (!previous || previous === next) return null

    const triggers = this.triggerTargets
    const forward = triggers.indexOf(next) > triggers.indexOf(previous)

    return forward ? `${prefix}-end` : `${prefix}-start`
  }

  // Two custom properties rather than a `left` and a `width`, because that is
  // what Radix publishes and the arrow's own transform already reads them.
  moveIndicator(trigger) {
    if (!this.hasIndicatorTarget) return

    const root = this.element.getBoundingClientRect()
    const rect = trigger.getBoundingClientRect()

    this.element.style.setProperty(
      "--radix-navigation-menu-indicator-size", `${rect.width}px`
    )
    this.element.style.setProperty(
      "--radix-navigation-menu-indicator-position", `${rect.left - root.left}px`
    )
    this.indicatorTarget.hidden = false
    this.indicatorTarget.dataset.state = "visible"
  }

  // --------------------------------------------------------------- helpers

  // A pointer event can arrive on a trigger or on a panel; both mean the same
  // item.
  triggerFor(element) {
    if (this.triggerTargets.includes(element)) return element

    const item = element.closest("[data-slot=navigation-menu-item]")

    return this.triggerTargets.find((trigger) => item?.contains(trigger)) || null
  }

  contentFor(trigger) {
    const item = trigger.closest("[data-slot=navigation-menu-item]")

    return this.contentTargets.find((content) => item?.contains(content)) || null
  }

  cancel() {
    if (this.timer) clearTimeout(this.timer)
    this.timer = null
  }
}
