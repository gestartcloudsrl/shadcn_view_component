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
import { ExitQueue } from "shadcn/animation"

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
    this.exits = new ExitQueue()
    this.reposition = this.reposition.bind(this)
  }

  show() {
    if (this.open) return
    this.open = true

    // Reopened before the exit finished — the wrapper, the placeholder and the
    // content are all still in place, so only the interaction state has to come
    // back. Rebuilding them would strand the old placeholder and leave a second
    // wrapper in the DOM.
    if (this.exits.has(this.content)) {
      this.exits.cancel(this.content)
    } else {
      this.mount()
    }

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

  // Leave a marker where the content was, so closing puts it back exactly
  // there. Appending to `home` instead would quietly reorder the markup —
  // after one open/close a Select's content ends up after the hidden input.
  mount() {
    this.placeholder = document.createComment("shadcn-floating-content")
    this.content.replaceWith(this.placeholder)

    this.wrapper = createWrapper()
    this.placeholder.parentNode.insertBefore(this.wrapper, this.placeholder)
    this.wrapper.appendChild(this.content)

    // Above every stacking context, without leaving the DOM.
    topLayer.enable(this.wrapper)
    topLayer.show(this.wrapper)
  }

  hide() {
    if (!this.open) return
    this.open = false

    // Everything here is interaction state, and all of it is immediate: a layer
    // that is fading out must not answer Escape or an outside click.
    window.removeEventListener("scroll", this.reposition, true)
    window.removeEventListener("resize", this.reposition)

    if (this.frame) cancelAnimationFrame(this.frame)
    this.frame = null

    if (this.layer) removeLayer(this.layer)
    this.layer = null

    // This is what starts the exit animation, so it has to be set before the
    // queue looks for one.
    this.content.dataset.state = "closed"
    if (this.trigger) this.trigger.dataset.state = "closed"

    this.exits.defer(this.content, () => this.dismount())

    this.onClose()
  }

  dismount() {
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
    // Turbo may be detaching the element; there is nothing to animate for and
    // nowhere to put the content back afterwards.
    this.exits.flushAll()
  }
}
