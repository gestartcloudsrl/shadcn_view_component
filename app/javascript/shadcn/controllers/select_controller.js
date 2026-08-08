import { Controller } from "@hotwired/stimulus"
import { uniqueId } from "shadcn/id"
import { FloatingLayer } from "shadcn/floating"
import { Typeahead } from "shadcn/typeahead"

// Radix's Select: a `role="combobox"` trigger driving a `role="listbox"` layer.
//
// The chosen item's label is copied into `[data-slot=select-value]` and the
// value is mirrored onto a hidden input so the control submits with the form,
// exactly like Radix's BubbleSelect.
export default class extends Controller {
  // `input` is the hidden field that submits with the form, which is why the
  // search box is `search`.
  static targets = [ "trigger", "content", "item", "value", "input", "search", "list", "empty" ]
  static values = {
    open: Boolean,
    value: String,
    placeholder: String,
    side: { type: String, default: "bottom" },
    align: { type: String, default: "center" },
    sideOffset: { type: Number, default: 4 },
    searchable: Boolean
  }

  connect() {
    if (!this.hasContentTarget || !this.hasTriggerTarget) return

    this.typeahead = new Typeahead()

    this.contentTarget.hidden = true
    this.contentTarget.id ||= uniqueId("shadcn-select")

    // The id is generated here, so the server has nothing to point this at.
    this.triggerTarget.setAttribute("aria-controls", this.contentTarget.id)
    this.triggerTarget.dataset.state = "closed"

    // `aria-activedescendant` needs something to point at, and the server
    // cannot know these ids. Generated here for the same reason the content's
    // is, and with the same helper: `crypto.randomUUID()` is secure-context
    // only, so it is `undefined` over plain HTTP.
    if (this.searchableValue && this.hasSearchTarget && this.hasListTarget) {
      this.listTarget.id ||= uniqueId("shadcn-select-list")
      this.searchTarget.setAttribute("aria-controls", this.listTarget.id)
      this.itemTargets.forEach((item) => (item.id ||= uniqueId("shadcn-select-item")))
    }

    this.layer = new FloatingLayer({
      trigger: this.triggerTarget,
      content: this.contentTarget,
      prefix: "select",
      side: this.sideValue,
      align: this.alignValue,
      sideOffset: this.sideOffsetValue,
      matchAnchorWidth: true,
      onOpen: () => {
        this.triggerTarget.setAttribute("aria-expanded", "true")
        // Radix resets here rather than on close (vendor/radix/ui/select.tsx:331-336),
        // so characters typed before this panel was last dismissed cannot join
        // the next search.
        this.typeahead.reset()
        // Focus goes to the search field, not the popover: a searchable select
        // is typed into the moment it opens.
        if (this.searchableValue && this.hasSearchTarget) {
          this.searchTarget.focus({ preventScroll: true })
        } else {
          this.contentTarget.focus({ preventScroll: true })
        }
        this.highlight(this.selectedItem || this.enabledItems[0])
      },
      onClose: () => {
        this.triggerTarget.setAttribute("aria-expanded", "false")
        this.clearHighlight()
        this.triggerTarget.focus({ preventScroll: true })
      }
    })

    this.render()
    if (this.openValue) this.layer.show()
  }

  disconnect() {
    if (this.layer) this.layer.destroy()
  }

  toggle() {
    this.layer.toggle()
  }

  triggerKeydown(event) {
    if (![ "ArrowDown", "ArrowUp", "Enter", " " ].includes(event.key)) return

    event.preventDefault()
    this.layer.show()
  }

  contentKeydown(event) {
    const items = this.enabledItems
    const current = items.indexOf(this.highlighted)

    switch (event.key) {
      // Clamp rather than wrap: Radix's own keydown handler slices the
      // candidate list from the current index and never wraps it back around
      // (vendor/radix/ui/select.tsx:904's
      // `candidateNodes = candidateNodes.slice(currentIndex + 1)`).
      case "ArrowDown":
        event.preventDefault()
        this.highlight(items[Math.min(current + 1, items.length - 1)])
        return
      // Radix reverses the candidates for ArrowUp before slicing
      // (vendor/radix/ui/select.tsx:898-904), so an index of -1 slices nothing
      // off the reversed list and focus enters at the end. `onOpen` always
      // highlights, which leaves one way to be here with items to move
      // through: a selected item that is *disabled*, which is what
      // `selectedItem` finds and what `enabledItems` leaves out.
      case "ArrowUp":
        event.preventDefault()
        this.highlight(current === -1 ? items[items.length - 1] : items[Math.max(current - 1, 0)])
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
        event.preventDefault()
        return
    }

    if (event.key.length === 1 && !event.metaKey && !event.ctrlKey) {
      const match = this.typeahead.search(event.key, this.enabledItems, this.highlighted)
      if (match) this.highlight(match)
    }
  }

  // shadcn's aria variant filters on substring rather than prefix — "err"
  // reaches Blueberry — and drops non-matching options from the DOM. Here they
  // are hidden instead: the options are server-rendered ERB, and one removed
  // cannot be put back.
  search() {
    const query = this.searchTarget.value.trim().toLowerCase()

    this.itemTargets.forEach((item) => {
      item.hidden = query !== "" && !item.textContent.trim().toLowerCase().includes(query)
    })

    const matches = this.enabledItems
    if (this.hasListTarget) this.listTarget.hidden = matches.length === 0
    if (this.hasEmptyTarget) this.emptyTarget.hidden = matches.length > 0

    this.highlight(matches[0])
  }

  pointerenter(event) {
    this.highlight(event.currentTarget)
  }

  select(event) {
    const item = event.currentTarget
    if (item.dataset.disabled !== undefined) return

    this.valueValue = item.dataset.value || ""
    this.render()
    this.layer.hide()
    this.dispatch("change", { detail: { value: this.valueValue } })

    if (this.hasInputTarget) {
      this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }
  }

  // --- helpers -------------------------------------------------------------

  // `!item.hidden` is what keeps the arrows, Home, End and `selectedItem` out
  // of rows the filter has taken away. Nothing hides items unless `searchable`,
  // so the plain select is unaffected.
  get enabledItems() {
    return this.itemTargets.filter((item) => item.dataset.disabled === undefined && !item.hidden)
  }

  get selectedItem() {
    return this.itemTargets.find((item) => (item.dataset.value || "") === this.valueValue) || null
  }

  get highlighted() {
    return this.itemTargets.find((item) => item.dataset.highlighted !== undefined) || null
  }

  highlight(item) {
    this.clearHighlight()
    if (!item) return

    item.dataset.highlighted = ""

    // Moving DOM focus would take it out of the search field and typing would
    // stop, so a searchable select points at the item instead of focusing it.
    if (this.searchableValue) {
      this.searchTarget.setAttribute("aria-activedescendant", item.id)
    } else {
      item.focus({ preventScroll: true })
    }

    item.scrollIntoView({ block: "nearest" })
  }

  clearHighlight() {
    this.itemTargets.forEach((item) => delete item.dataset.highlighted)
    if (this.searchableValue && this.hasSearchTarget) {
      this.searchTarget.removeAttribute("aria-activedescendant")
    }
  }

  render() {
    const selected = this.selectedItem

    this.itemTargets.forEach((item) => {
      const isSelected = item === selected
      item.setAttribute("aria-selected", String(isSelected))
      item.dataset.state = isSelected ? "checked" : "unchecked"

      const indicator = item.querySelector("[data-slot='select-item-indicator'] > *")
      if (indicator) indicator.hidden = !isSelected
    })

    if (this.hasValueTarget) {
      this.valueTarget.textContent = selected
        ? selected.querySelector("[data-slot='select-item-text']")?.textContent.trim() ||
          selected.textContent.trim()
        : this.placeholderValue
    }

    if (selected) {
      delete this.triggerTarget.dataset.placeholder
    } else {
      this.triggerTarget.dataset.placeholder = ""
    }

    if (this.hasInputTarget) this.inputTarget.value = this.valueValue
  }
}
