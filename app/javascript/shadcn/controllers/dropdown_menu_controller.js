import { Controller } from "@hotwired/stimulus"
import { uniqueId } from "shadcn/id"
import { FloatingLayer } from "shadcn/floating"
import { Typeahead } from "shadcn/typeahead"

// Radix's own: 100ms before a hovered sub-trigger opens (menu.tsx:1123), and
// 300ms of grace after the pointer leaves it (menu.tsx:1157-1160).
const SUB_OPEN_DELAY = 100
const SUB_GRACE_DELAY = 300

// Radix's DropdownMenu: a `role="menu"` layer with the ARIA menu keyboard
// pattern — arrow keys move a `data-highlighted` cursor, typing jumps to a
// matching item, Escape closes and returns focus to the trigger.
export default class extends Controller {
  static targets = [ "trigger", "content", "item" ]
  static values = {
    open: Boolean,
    // The `--radix-*` custom properties the content's classes read. The context
    // menu is this same controller with a different prefix and a different way
    // in — its markup, its keyboard and its submenus are the dropdown's, which
    // is why it has no controller of its own. The Sheet reuses the dialog's for
    // the same reason.
    prefix: { type: String, default: "dropdown-menu" },
    side: { type: String, default: "bottom" },
    align: { type: String, default: "start" },
    sideOffset: { type: Number, default: 4 },
    alignOffset: { type: Number, default: 0 },
    loop: Boolean
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
      prefix: this.prefixValue,
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
        // Radix's menu clears the buffer on blur rather than on close
        // (vendor/radix/ui/menu.tsx:585-590). Closing is where the focus this
        // layer owns actually leaves — nothing here listens for focusout, so a
        // menu that lost focus *without* closing would keep its buffer, which
        // Radix's would not. No path in this gem does that: Tab, Escape and an
        // outside click all close first.
        this.typeahead.reset()
        this.triggerTarget.focus({ preventScroll: true })
      }
    })

    if (this.openValue) this.layer.show()
  }

  disconnect() {
    this.cancelSubTimers()
    if (this.layer) this.layer.destroy()
  }

  toggle() {
    this.layer.toggle()
  }

  // A right-click opens the menu *at the pointer*, so the layer is measured
  // against a point rather than against the element that was pressed. Radix
  // does the same with a virtual element; `popper.js` only ever calls
  // `getBoundingClientRect`, so a zero-sized rect at the coordinates is the
  // whole of it.
  openAtPointer(event) {
    event.preventDefault()

    const { clientX: x, clientY: y } = event

    this.layer.anchor = {
      getBoundingClientRect: () => ({
        top: y, bottom: y, left: x, right: x, width: 0, height: 0, x, y
      })
    }

    this.layer.hide()
    this.layer.show()
  }

  // Submenus open on hover, like Radix's SubTrigger — after 100ms, so crossing
  // a trigger on the way somewhere else does not open it (menu.tsx:1123).
  open() {
    this.cancelSubTimers()
    this.subTimer = setTimeout(() => this.layer.show(), SUB_OPEN_DELAY)
  }

  close() {
    this.cancelSubTimers()
    this.layer.hide()
  }

  // Leaving the trigger, or the panel, starts a close the other one can cancel
  // by being arrived at. Without it a submenu opened by hovering stays open for
  // as long as the menu does, because nothing else was ever going to shut it.
  //
  // Radix grants the same grace but shapes it: a polygon from the exit point to
  // the panel's edges, honoured only while the pointer is *moving toward* it
  // (menu.tsx:1136-1160). This is the time half without the direction half —
  // more forgiving, never less. See features/README.md.
  closeLater() {
    this.cancelSubTimers()
    this.subTimer = setTimeout(() => this.layer.hide(), SUB_GRACE_DELAY)
  }

  cancelSubTimers() {
    if (this.subTimer) clearTimeout(this.subTimer)
    this.subTimer = null
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
      // Clamp unless asked to wrap, which is how RovingFocusGroup branches:
      // `context.loop ? wrapArray(...) : candidateNodes.slice(currentIndex + 1)`
      // (vendor/radix/ui/roving-focus-group.tsx:324-326) — the slice is empty
      // at the end, so focus stays put. `loop` is opt-in in Radix's menu too
      // (vendor/radix/ui/menu.tsx:387), and vendor/shadcn/ui/dropdown-menu.tsx
      // never passes it, so `false` is the shadcn default rather than a choice
      // made here.
      case "ArrowDown":
        event.preventDefault()
        this.highlight(this.step(items, current, 1))
        return
      // With nothing highlighted yet — which is where a click-open leaves the
      // menu — ArrowUp enters at the *end*: Radix lists it in `LAST_KEYS` and
      // reverses the candidates before `focusFirst`
      // (vendor/radix/ui/menu.tsx:576-583).
      case "ArrowUp":
        event.preventDefault()
        this.highlight(current === -1 ? items[items.length - 1] : this.step(items, current, -1))
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
      const match = this.typeahead.search(event.key, this.enabledItems, this.highlighted)
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

  // One step along `items` from `current`, wrapping only when `loop` is set.
  // With nothing highlighted `current` is -1, so a forward step lands on the
  // first item either way.
  step(items, current, delta) {
    const next = current + delta
    return this.loopValue
      ? items[(next + items.length) % items.length]
      : items[Math.min(Math.max(next, 0), items.length - 1)]
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
