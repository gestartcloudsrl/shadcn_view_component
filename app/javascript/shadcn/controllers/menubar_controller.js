import { Controller } from "@hotwired/stimulus"
import { directionAwareKey, readDirection } from "shadcn/direction"

// Radix's Menubar (vendor/radix/ui/menubar.tsx).
//
// Every menu in the bar is a `shadcn--dropdown-menu` of its own, as a context
// menu's submenus are. This controller is the *bar*: one menu open at a time,
// arrows moving between the names, and — the part that makes it feel like a
// menubar rather than a row of dropdowns — a menu already open turning the rest
// into things you merely hover to reach.
export default class extends Controller {
  static targets = [ "trigger", "menu" ]
  static values = {
    // Radix's default here is `true` (vendor/radix/ui/menubar.tsx:76), unlike the dropdown's.
    // A bar is a ring; a list is not.
    loop: { type: Boolean, default: true }
  }

  // Which menu is open, if any. Read from the DOM rather than held, so the
  // answer cannot drift from what the menus themselves did.
  get openTrigger() {
    return this.triggerTargets.find((trigger) => trigger.dataset.state === "open") || null
  }

  // Once one is open, crossing another name switches to it — no click, and the
  // focus follows so the keyboard carries on from where the pointer left off
  // (vendor/radix/ui/menubar.tsx:255-260).
  pointerEnter(event) {
    const trigger = event.currentTarget
    const open = this.openTrigger

    if (!open || open === trigger) return

    this.closeAll(trigger)
    this.menuFor(trigger)?.toggle()
    trigger.focus()
  }

  keydown(event) {
    const key = directionAwareKey(event.key, readDirection(this.element))
    const triggers = this.triggerTargets
    const index = triggers.indexOf(event.currentTarget)

    if (index === -1) return

    switch (key) {
      case "ArrowRight":
        event.preventDefault()
        this.move(index, 1)
        return
      case "ArrowLeft":
        event.preventDefault()
        this.move(index, -1)
        return
      case "Home":
        event.preventDefault()
        triggers[0].focus()
        return
      case "End":
        event.preventDefault()
        triggers[triggers.length - 1].focus()
    }
  }

  // The arrows keep working from inside an open panel, which is how you walk
  // the whole bar without closing anything. Around a submenu they give way —
  // but only in the one direction that already means something there, which is
  // the half easy to get wrong (vendor/radix/ui/menubar.tsx:355-359):
  //
  //   on a sub-trigger, "next" opens the submenu — so only "next" gives way,
  //   and "previous" still walks the bar;
  //   inside a submenu, "previous" closes it — so only "previous" gives way,
  //   and "next" still walks the bar.
  contentKeydown(event) {
    const key = directionAwareKey(event.key, readDirection(this.element))
    if (key !== "ArrowRight" && key !== "ArrowLeft") return

    const panel = event.currentTarget
    const next = key === "ArrowRight"

    if (next && event.target.closest("[data-slot=menubar-sub-trigger]")) return
    if (!next && event.target.closest("[data-slot=menubar-sub-content]")) return

    const trigger = this.triggerFor(panel)
    const index = this.triggerTargets.indexOf(trigger)
    if (index === -1) return

    event.preventDefault()
    this.move(index, next ? 1 : -1, { open: true })
  }

  // Focus alone does not open anything — it only moves the tab stop. Radix
  // manages that stop by hand rather than through the roving group, because the
  // group would fight the menu for it (vendor/radix/ui/menubar.tsx:89-92).
  focused(event) {
    for (const trigger of this.triggerTargets) {
      trigger.tabIndex = trigger === event.currentTarget ? 0 : -1
    }
  }

  move(index, step, { open = false } = {}) {
    const triggers = this.triggerTargets
    const last = triggers.length - 1
    let next = index + step

    if (next > last) next = this.loopValue ? 0 : last
    if (next < 0) next = this.loopValue ? last : 0

    const target = triggers[next]
    const opening = open || this.openTrigger

    if (opening) {
      this.closeAll(target)
      this.menuFor(target)?.toggle()

      // and nothing else: the panel that just opened has taken focus, and
      // focusing the name would take it straight back off it. Radix goes out of
      // its way to leave the trigger unfocused on the way in — pointerdown
      // calls `preventDefault` for exactly this reason
      // (vendor/radix/ui/menubar.tsx:245-252) — and this is the same move by
      // another route.
      return
    }

    target.focus()
  }

  closeAll(except) {
    for (const trigger of this.triggerTargets) {
      if (trigger === except || trigger.dataset.state !== "open") continue

      this.menuFor(trigger)?.toggle()
    }
  }

  // Reaching the menu's own controller rather than poking its DOM: it owns the
  // layer, the dismiss registration and the exit, and setting attributes behind
  // its back would leave all three out of step.
  menuFor(trigger) {
    const element = trigger.closest("[data-slot=menubar-menu]")
    if (!element) return null

    return this.application.getControllerForElementAndIdentifier(element, "shadcn--dropdown-menu")
  }

  triggerFor(panel) {
    const element = panel.closest("[data-slot=menubar-menu]")

    return this.triggerTargets.find((trigger) => element?.contains(trigger)) || null
  }
}
