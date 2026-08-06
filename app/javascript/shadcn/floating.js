// Shared open/close machinery for the popper-based components (popover,
// dropdown menu, select, tooltip).
//
// Radix renders floating content through a portal on `document.body`. We keep
// it inside the component instead, wrapped in the same fixed-position element
// Radix uses (`data-radix-popper-content-wrapper`). The component roots are
// `display: contents`, so a fixed wrapper still positions against the viewport,
// and staying in place is what keeps the Stimulus actions on the items — menu
// items, select options, close buttons — bound and working.

import { createWrapper, position } from "shadcn/popper"
import * as topLayer from "shadcn/top_layer"
import { pushLayer, removeLayer } from "shadcn/dismiss"

export class FloatingLayer {
  constructor(options) {
    this.trigger = options.trigger
    this.content = options.content
    this.home = options.home || this.content.parentElement
    this.prefix = options.prefix || "popper"
    this.side = options.side || "bottom"
    this.align = options.align || "center"
    this.sideOffset = options.sideOffset || 0
    this.alignOffset = options.alignOffset || 0
    this.matchAnchorWidth = options.matchAnchorWidth || false
    this.onOpen = options.onOpen || (() => {})
    this.onClose = options.onClose || (() => {})
    this.onDismiss = options.onDismiss || null

    this.open = false
    this.wrapper = null
    this.layer = null
    this.placeholder = null
    this.frame = null
    this.reposition = this.reposition.bind(this)
  }

  show() {
    if (this.open) return
    this.open = true

    // Leave a marker where the content was, so closing puts it back exactly
    // there. Appending to `home` instead would quietly reorder the markup —
    // after one open/close a Select's content ends up after the hidden input.
    this.placeholder = document.createComment("shadcn-floating-content")
    this.content.replaceWith(this.placeholder)

    this.wrapper = createWrapper()
    this.placeholder.parentNode.insertBefore(this.wrapper, this.placeholder)
    this.wrapper.appendChild(this.content)

    // Above every stacking context, without leaving the DOM.
    topLayer.enable(this.wrapper)
    topLayer.show(this.wrapper)

    this.content.hidden = false
    this.content.dataset.state = "open"
    if (this.trigger) this.trigger.dataset.state = "open"

    this.applyPosition()

    window.addEventListener("scroll", this.reposition, true)
    window.addEventListener("resize", this.reposition)

    this.layer = pushLayer({
      element: this.content,
      anchors: [ this.trigger ],
      onDismiss: (event) => (this.onDismiss ? this.onDismiss(event) : this.hide())
    })

    this.onOpen()
  }

  hide() {
    if (!this.open) return
    this.open = false

    window.removeEventListener("scroll", this.reposition, true)
    window.removeEventListener("resize", this.reposition)

    if (this.frame) cancelAnimationFrame(this.frame)
    this.frame = null

    if (this.layer) removeLayer(this.layer)
    this.layer = null

    this.content.dataset.state = "closed"
    if (this.trigger) this.trigger.dataset.state = "closed"
    this.content.hidden = true

    if (this.placeholder?.parentNode) {
      this.placeholder.replaceWith(this.content)
    } else {
      this.home.appendChild(this.content)
    }
    this.placeholder = null

    if (this.wrapper) {
      topLayer.hide(this.wrapper)
      this.wrapper.remove()
    }
    this.wrapper = null

    this.onClose()
  }

  toggle() {
    this.open ? this.hide() : this.show()
  }

  // Bound to `scroll` (capture, so every scrolling ancestor fires it) and to
  // `resize`. Positioning writes a transform and then reads `offsetWidth`,
  // which forces a synchronous layout, so coalesce into one frame instead of
  // reflowing on every event.
  reposition() {
    if (!this.open || !this.trigger || this.frame) return

    this.frame = requestAnimationFrame(() => {
      this.frame = null
      this.applyPosition()
    })
  }

  // The opening position cannot wait for a frame: the wrapper starts at the
  // top-left of the viewport, so a deferred first placement flashes there.
  applyPosition() {
    if (!this.open || !this.trigger) return

    position(this.trigger, this.content, {
      side: this.side,
      align: this.align,
      sideOffset: this.sideOffset,
      alignOffset: this.alignOffset,
      prefix: this.prefix,
      matchAnchorWidth: this.matchAnchorWidth
    })
  }

  destroy() {
    this.hide()
  }
}
