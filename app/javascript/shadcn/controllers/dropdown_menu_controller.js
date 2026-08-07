import { Controller } from "@hotwired/stimulus"
import { uniqueId } from "shadcn/id"
import { FloatingLayer } from "shadcn/floating"
import { Typeahead } from "shadcn/typeahead"

// Radix's DropdownMenu: a `role="menu"` layer with the ARIA menu keyboard
// pattern — arrow keys move a `data-highlighted` cursor, typing jumps to a
// matching item, Escape closes and returns focus to the trigger.
export default class extends Controller {
  static targets = [ "trigger", "content", "item" ]
  static values = {
    open: Boolean,
    side: { type: String, default: "bottom" },
    align: { type: String, default: "start" },
    sideOffset: { type: Number, default: 4 },
    alignOffset: { type: Number, default: 0 }
  }

  connect() {
    if (!this.hasContentTarget || !this.hasTriggerTarget) return

    this.typeahead = new Typeahead()

    this.contentTarget.hidden = true
    this.contentTarget.id ||= uniqueId("shadcn-dropdown")

    // The id is generated here, so the server has nothing to point this at.
    this.triggerTarget.setAttribute("aria-controls", this.contentTarget.id)
    this.triggerTarget.dataset.state = "closed"

    this.layer = new FloatingLayer({
      trigger: this.triggerTarget,
      content: this.contentTarget,
      prefix: "dropdown-menu",
      side: this.sideValue,
      align: this.alignValue,
      sideOffset: this.sideOffsetValue,
      alignOffset: this.alignOffsetValue,
      onOpen: () => {
        this.triggerTarget.setAttribute("aria-expanded", "true")
        this.contentTarget.focus({ preventScroll: true })
      },
      onClose: () => {
        this.triggerTarget.setAttribute("aria-expanded", "false")
        this.clearHighlight()
        this.triggerTarget.focus({ preventScroll: true })
      }
    })

    if (this.openValue) this.layer.show()
  }

  disconnect() {
    if (this.layer) this.layer.destroy()
  }

  toggle() {
    this.layer.toggle()
  }

  // Submenus open on hover, like Radix's SubTrigger.
  open() {
    this.layer.show()
  }

  close() {
    this.layer.hide()
  }

  // Opening with ArrowDown/ArrowUp lands on the first/last item, like Radix.
  triggerKeydown(event) {
    if (![ "ArrowDown", "ArrowUp", "Enter", " " ].includes(event.key)) return

    event.preventDefault()
    this.layer.show()

    const items = this.enabledItems
    if (items.length === 0) return
    this.highlight(event.key === "ArrowUp" ? items[items.length - 1] : items[0])
  }

  contentKeydown(event) {
    const items = this.enabledItems
    const current = items.indexOf(this.highlighted)

    switch (event.key) {
      // Clamp rather than wrap: Radix's MenuContentImpl destructures
      // `loop = false` (vendor/radix/ui/menu.tsx:387) and shadcn never passes
      // `loop`, and RovingFocusGroup only wraps when that flag is set
      // (vendor/radix/ui/roving-focus-group.tsx:324's
      // `context.loop ? wrapArray(...) : candidateNodes.slice(...)`).
      case "ArrowDown":
        event.preventDefault()
        this.highlight(items[Math.min(current + 1, items.length - 1)])
        return
      case "ArrowUp":
        event.preventDefault()
        this.highlight(items[Math.max(current - 1, 0)])
        return
      case "Home":
        event.preventDefault()
        this.highlight(items[0])
        return
      case "End":
        event.preventDefault()
        this.highlight(items[items.length - 1])
        return
      case "Enter":
      case " ":
        if (!this.highlighted) return
        event.preventDefault()
        this.highlighted.click()
        return
      case "Tab":
        this.layer.hide()
        return
    }

    if (event.key.length === 1 && !event.metaKey && !event.ctrlKey) {
      const match = this.typeahead.search(event.key, this.enabledItems)
      if (match) this.highlight(match)
    }
  }

  pointerenter(event) {
    this.highlight(event.currentTarget)
  }

  select(event) {
    const item = event.currentTarget
    if (item.dataset.disabled !== undefined) return

    if (item.getAttribute("role") === "menuitemcheckbox") {
      const checked = item.getAttribute("aria-checked") === "true"
      this.setChecked(item, !checked)
      return
    }

    if (item.getAttribute("role") === "menuitemradio") {
      this.radioSiblings(item).forEach((sibling) => this.setChecked(sibling, sibling === item))
      return
    }

    this.layer.hide()
  }

  // --- helpers -------------------------------------------------------------

  get enabledItems() {
    return this.itemTargets.filter((item) => item.dataset.disabled === undefined)
  }

  get highlighted() {
    return this.itemTargets.find((item) => item.dataset.highlighted !== undefined) || null
  }

  highlight(item) {
    this.clearHighlight()
    if (!item) return

    item.dataset.highlighted = ""
    item.focus({ preventScroll: true })
    item.scrollIntoView({ block: "nearest" })
  }

  clearHighlight() {
    this.itemTargets.forEach((item) => delete item.dataset.highlighted)
  }

  setChecked(item, checked) {
    item.setAttribute("aria-checked", String(checked))
    item.dataset.state = checked ? "checked" : "unchecked"

    const indicator = item.querySelector("[data-slot$='-item-indicator']")
    if (indicator) indicator.hidden = !checked
  }

  radioSiblings(item) {
    const group = item.closest("[data-slot='dropdown-menu-radio-group']") || this.contentTarget
    return Array.from(group.querySelectorAll("[role='menuitemradio']"))
  }
}
