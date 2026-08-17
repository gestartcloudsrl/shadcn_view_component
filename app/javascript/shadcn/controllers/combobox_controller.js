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
  static targets = [ "search", "content", "list", "item", "indicator", "input", "trigger", "clear",
    "chip", "chips", "chipTemplate" ]

  static values = {
    open: Boolean,
    value: String,
    multiple: Boolean,
    values: Array,
    name: String,
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

    // Kept so it can be put back when the last chip goes. Read once, before
    // anything has had a chance to blank it.
    this.placeholder = this.searchTarget.getAttribute("placeholder") ?? ""
    this.syncPlaceholder()
  }

  // Upstream's multiple example writes `placeholder={value.length > 0 ? '' :
  // 'e.g. TypeScript'}` — the placeholder belongs to an empty control, and once
  // there are chips they are what the field is saying. There the caller does
  // it, because there the caller re-renders; here the chips come and go under
  // the controller, so the controller owns it.
  //
  // Called from `connect` as well, not only after a change: the server can
  // render a field that already has chips beside it, and it did — the preview
  // starts with two.
  syncPlaceholder() {
    if (!this.multipleValue) return

    this.searchTarget.setAttribute("placeholder", this.valuesValue.length > 0 ? "" : this.placeholder)
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

    // Backspace on an empty field takes the last chip back off. This one is
    // **ours**: Base UI's documentation does not describe a Backspace
    // behaviour, and Base UI itself is not vendored here, so it could not be
    // checked the way the rest of this family was. It is the convention every
    // token field on the web follows, and it is the only way to undo a chip
    // from the keyboard — the X is a pointer target.
    if (this.multipleValue && event.key === "Backspace" && this.searchTarget.value === "") {
      const last = this.chipTargets.at(-1)
      if (last) {
        event.preventDefault()
        this.drop(last.dataset.value ?? "")
      }
      return
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
    this.searchTarget.value = ""

    if (this.multipleValue) {
      // Every chip, not just the field: in multiple mode the chosen set *is*
      // what the control holds, and leaving the tokens behind would make Clear
      // look like it had done nothing.
      for (const chip of this.chipTargets) chip.remove()
      this.valuesValue = []
      this.writeInputs()
      this.syncPlaceholder()
    } else {
      this.valueValue = ""
      if (this.hasInputTarget) this.inputTarget.value = ""
    }

    this.mark()
    this.search()
    this.searchTarget.focus()
  }

  // A chip taken back off, by its X.
  remove(event) {
    event.preventDefault()
    const chip = event.currentTarget.closest("[data-slot=combobox-chip]")
    if (!chip) return

    this.drop(chip.dataset.value ?? "", chip)
  }

  take(item) {
    if (!item || item.dataset.disabled !== undefined) return

    const value = item.dataset.value ?? ""

    if (this.multipleValue) return this.toggle_value(value, item)

    this.valueValue = value
    this.searchTarget.value = item.dataset.label || this.textOf(item)
    if (this.hasInputTarget) this.inputTarget.value = this.valueValue

    this.mark()
    this.close()
    this.searchTarget.focus()
    this.dispatch("select", { detail: { value: this.valueValue, item } })
  }

  // Multiple selection. Taking an option that is already taken puts it back —
  // which is what the tick in the list invites, and what leaves the list and
  // the chips describing the same set. Base UI's documentation does not say
  // either way, and Base UI is not vendored here, so this is **ours**.
  //
  // The panel stays open and the field is emptied, which the documentation's
  // own multiple example does show.
  toggle_value(value, item) {
    if (this.valuesValue.includes(value)) return this.drop(value)

    this.valuesValue = [ ...this.valuesValue, value ]
    this.addChip(value, item.dataset.label || this.textOf(item))
    this.writeInputs()
    this.syncPlaceholder()

    this.searchTarget.value = ""
    this.search()
    this.mark()
    this.searchTarget.focus()
    this.dispatch("select", { detail: { value, item } })
  }

  drop(value, chip = null) {
    const token = chip || this.chipTargets.find((c) => (c.dataset.value ?? "") === value)
    token?.remove()

    if (this.multipleValue) {
      this.valuesValue = this.valuesValue.filter((v) => v !== value)
      this.writeInputs()
      this.syncPlaceholder()
      this.mark()
    }

    this.dispatch("remove", { detail: { value } })
    this.searchTarget.focus()
  }

  // A chip per chosen value, cloned from the `<template>` the Chips component
  // renders — so the class strings stay in Ruby, where `parity_spec` reads
  // them, instead of being copied into this file.
  addChip(value, label) {
    if (!this.hasChipsTarget || !this.hasChipTemplateTarget) return

    const chip = this.chipTemplateTarget.content.firstElementChild.cloneNode(true)
    chip.dataset.value = value

    const remove = chip.querySelector("[data-slot=combobox-chip-remove]")
    if (remove) remove.dataset.value = value

    // Before the remove button, which the Chip component renders last.
    chip.insertBefore(document.createTextNode(label), remove)

    // Before the field, not before the `<template>`. The template is the last
    // child, so inserting there put every new chip *after* the input: the ones
    // the server rendered sat to its left and the ones taken since to its
    // right, with the field stranded in the middle. The field is the anchor —
    // upstream's chips box is a row of tokens with the input taking whatever is
    // left of the last line.
    this.chipsTarget.insertBefore(chip, this.searchTarget)
  }

  // One hidden input per chosen value, rewritten whenever the set changes. The
  // first input the component rendered carries the empty value that keeps the
  // parameter present when every chip is gone, and is left alone — it has no
  // target, so it is not in `inputTargets` to begin with.
  writeInputs() {
    if (!this.hasNameValue) return

    for (const input of this.inputTargets) input.remove()

    for (const value of this.valuesValue) {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = this.nameValue
      input.value = value
      input.autocomplete = "off"
      // `setAttribute`, not `dataset`: the controller's identifier contains a
      // double dash, and `data-shadcn--combobox-target` has no camelCase form
      // `dataset` round-trips to.
      input.setAttribute("data-shadcn--combobox-target", "input")
      this.element.appendChild(input)
    }
  }

  // The tick, which is the only thing that says which ones were taken once the
  // panel is closed and reopened.
  mark() {
    for (const item of this.itemTargets) {
      const value = item.dataset.value ?? ""
      const chosen = this.multipleValue
        ? this.valuesValue.includes(value)
        : value === this.valueValue && this.valueValue !== ""

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
