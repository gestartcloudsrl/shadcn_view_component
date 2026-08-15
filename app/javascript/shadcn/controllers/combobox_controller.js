import { Controller } from "@hotwired/stimulus"
import { uniqueId } from "shadcn/id"
import { FloatingLayer } from "shadcn/floating"

// Base UI's Combobox: a text field that filters a listbox and keeps the caret.
//
// It is the only family here answerable to Base UI rather than Radix, and the
// difference is in the names rather than in the behaviour — `data-open` where
// everything else writes `data-state="open"`, `--anchor-width` where everything
// else reads `--radix-popper-anchor-width`. The arrangement itself is the
// searchable select's: virtual focus through `aria-activedescendant`, the caret
// never leaving the input.
export default class extends Controller {
  static targets = [ "search", "content", "list", "item", "indicator", "input", "trigger", "clear", "chip" ]

  static values = {
    open: Boolean,
    value: String,
    side: { type: String, default: "bottom" },
    align: { type: String, default: "start" },
    sideOffset: { type: Number, default: 6 },
    alignOffset: { type: Number, default: 0 }
  }

  connect() {
    if (!this.hasContentTarget || !this.hasSearchTarget) return

    this.contentTarget.id ||= uniqueId("shadcn-combobox-content")
    this.searchTarget.setAttribute("aria-controls", this.contentTarget.id)

    this.layer = new FloatingLayer({
      trigger: this.searchTarget,
      content: this.contentTarget,
      prefix: "combobox",
      side: this.sideValue,
      align: this.alignValue,
      sideOffset: this.sideOffsetValue,
      alignOffset: this.alignOffsetValue,
      matchAnchorWidth: true,
      // The four unprefixed names Base UI publishes and this component's own
      // classes read: `w-(--anchor-width)`, `max-w-(--available-width)`,
      // `origin-(--transform-origin)`. Asked for by this family and by no
      // other, so a host's page gets them only where a combobox is.
      publishBaseUiVariables: true,
      onOpen: () => this.opened(),
      onClose: () => this.closed()
    })
  }

  disconnect() {
    this.layer?.destroy()
  }

  toggle(event) {
    event.preventDefault()
    this.openValue ? this.close() : this.open()
  }

  open() {
    if (this.openValue) return

    this.openValue = true
    this.layer.show()
  }

  close() {
    if (!this.openValue) return

    this.openValue = false
    this.layer.hide()
  }

  opened() {
    // Base UI's own state attributes, which are what the panel's classes read.
    this.contentTarget.dataset.open = ""
    delete this.contentTarget.dataset.closed
    this.searchTarget.setAttribute("aria-expanded", "true")
    this.highlight(this.chosenItem || this.visibleItems[0])
  }

  closed() {
    this.contentTarget.dataset.closed = ""
    delete this.contentTarget.dataset.open
    this.searchTarget.setAttribute("aria-expanded", "false")
    this.searchTarget.removeAttribute("aria-activedescendant")
  }

  // Base UI's default filter is a contains match, which is also what the
  // searchable select does — a combobox completes a value the caller already
  // ordered, where the palette ranks answers. Same reasoning, opposite ends.
  search() {
    const query = this.searchTarget.value.trim().toLowerCase()

    for (const item of this.itemTargets) {
      item.hidden = query !== "" && !this.textOf(item).toLowerCase().includes(query)
    }

    // `data-empty` on the *content*, because that is what the empty state's
    // own class reads: `group-data-empty/combobox-content:flex`.
    if (this.visibleItems.length === 0) this.contentTarget.dataset.empty = ""
    else delete this.contentTarget.dataset.empty

    this.open()
    this.highlight(this.visibleItems[0])
  }

  keydown(event) {
    const keys = {
      ArrowDown: () => (this.openValue ? this.move(1) : this.open()),
      ArrowUp: () => (this.openValue ? this.move(-1) : this.open()),
      Home: () => this.highlight(this.visibleItems[0]),
      End: () => this.highlight(this.visibleItems.at(-1)),
      Enter: () => this.take(this.highlighted),
      Escape: () => this.close()
    }
    const act = keys[event.key]
    if (!act) return

    // Tab is deliberately absent: it leaves the field, which is what Tab does.
    event.preventDefault()
    act()
  }

  hover(event) {
    this.highlight(event.currentTarget)
  }

  choose(event) {
    this.take(event.currentTarget)
  }

  clear(event) {
    event.preventDefault()
    this.valueValue = ""
    this.searchTarget.value = ""
    if (this.hasInputTarget) this.inputTarget.value = ""

    this.mark()
    this.search()
    this.searchTarget.focus()
  }

  // A chip taken back off. Removing is self-contained — the token goes and the
  // page is told which value left — where *adding* one is the other half of
  // multiple selection and is not wired yet; see features/combobox.md.
  remove(event) {
    event.preventDefault()
    const chip = event.currentTarget.closest("[data-slot=combobox-chip]")
    if (!chip) return

    const value = chip.dataset.value ?? ""
    chip.remove()
    this.dispatch("remove", { detail: { value } })
    this.searchTarget.focus()
  }

  take(item) {
    if (!item || item.dataset.disabled !== undefined) return

    this.valueValue = item.dataset.value ?? ""
    this.searchTarget.value = item.dataset.label || this.textOf(item)
    if (this.hasInputTarget) this.inputTarget.value = this.valueValue

    this.mark()
    this.close()
    this.searchTarget.focus()
    this.dispatch("select", { detail: { value: this.valueValue, item } })
  }

  // The tick, which is the only thing that says which one was taken once the
  // panel is closed and reopened.
  mark() {
    for (const item of this.itemTargets) {
      const chosen = (item.dataset.value ?? "") === this.valueValue && this.valueValue !== ""

      item.setAttribute("aria-selected", String(chosen))
      const indicator = item.querySelector("[data-slot=combobox-item-indicator]")
      if (indicator) indicator.hidden = !chosen
    }
  }

  move(by) {
    const items = this.visibleItems
    if (items.length === 0) return

    const at = items.indexOf(this.highlighted)
    this.highlight(items[(at + by + items.length) % items.length])
  }

  highlight(item) {
    for (const other of this.itemTargets) {
      if (other === item) other.dataset.highlighted = ""
      else delete other.dataset.highlighted
    }

    if (item) this.searchTarget.setAttribute("aria-activedescendant", item.id)
    else this.searchTarget.removeAttribute("aria-activedescendant")

    item?.scrollIntoView({ block: "nearest" })
  }

  get highlighted() {
    return this.itemTargets.find((item) => item.dataset.highlighted !== undefined)
  }

  get chosenItem() {
    return this.itemTargets.find((item) => (item.dataset.value ?? "") === this.valueValue && this.valueValue !== "")
  }

  get visibleItems() {
    return this.itemTargets.filter((item) => !item.hidden && item.dataset.disabled === undefined)
  }

  textOf(item) {
    return item.dataset.label || item.textContent.trim().replace(/\s+/g, " ")
  }
}
