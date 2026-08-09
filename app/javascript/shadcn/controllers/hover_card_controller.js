import { Controller } from "@hotwired/stimulus"
import { FloatingLayer } from "shadcn/floating"

// Radix's HoverCard (vendor/radix/ui/hover-card.tsx): a card that opens on
// hover after a pause and closes after a longer one.
//
// The closing delay is the whole design. It is the window in which the pointer
// crosses the gap between the trigger and the card — and the card carries the
// same enter and leave handlers as the trigger, so arriving on it cancels the
// close that leaving the trigger started.
export default class extends Controller {
  static targets = [ "trigger", "content" ]
  static values = {
    side: { type: String, default: "bottom" },
    align: { type: String, default: "center" },
    sideOffset: { type: Number, default: 4 },
    // Radix's own (hover-card.tsx:59-60).
    openDelay: { type: Number, default: 700 },
    closeDelay: { type: Number, default: 300 }
  }

  connect() {
    if (!this.hasTriggerTarget || !this.hasContentTarget) return

    this.contentTarget.hidden = true

    // The card is not reachable by keyboard — it opens on the trigger's focus
    // and there is nowhere to tab to — so anything inside it that would be a
    // tab stop is taken out of the order. Radix does this on every render
    // (hover-card.tsx:324-327); here the content is the host's markup and does
    // not change under us, so once is enough.
    this.excludeTabbables()

    this.layer = new FloatingLayer({
      trigger: this.triggerTarget,
      content: this.contentTarget,
      prefix: "hover-card",
      side: this.sideValue,
      align: this.alignValue,
      sideOffset: this.sideOffsetValue
    })
  }

  disconnect() {
    this.cancel()
    this.layer?.destroy()
  }

  // `pointerenter` rather than `mouseenter`, because that is the event that
  // carries a `pointerType`: Radix excludes touch, where there is no hovering
  // to do and a tap would open a card the same tap is trying to activate.
  open(event) {
    if (this.isTouch(event)) return

    this.cancel()
    this.timer = setTimeout(() => this.layer.show(), this.openDelayValue)
  }

  close(event) {
    if (this.isTouch(event)) return

    this.cancel()
    this.timer = setTimeout(() => this.layer.hide(), this.closeDelayValue)
  }

  cancel() {
    if (this.timer) clearTimeout(this.timer)
    this.timer = null
  }

  // `focus` and `blur` are not pointer events and have no `pointerType`, so an
  // absent one is a real interaction rather than a touch.
  isTouch(event) {
    return event?.pointerType === "touch"
  }

  excludeTabbables() {
    const selector =
      "a[href], button, input, select, textarea, [tabindex]:not([tabindex='-1'])"

    for (const element of this.contentTarget.querySelectorAll(selector)) {
      element.setAttribute("tabindex", "-1")
    }
  }
}
