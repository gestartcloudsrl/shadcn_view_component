// A one-second character buffer shared by any roving-focus list (menu items,
// select options): each keystroke is appended to the buffer, which clears
// itself after a second of silence, and the caller gets back whichever item's
// text starts with the buffer so far.
//
// Deliberately does not know how the caller moves focus — that stays in each
// controller, which owns its own item list and highlighting.
//
// Always searches from the start of the list, unlike Radix's findNextItem
// (vendor/radix/ui/select.tsx:1917), which searches forward from the
// currently highlighted item and cycles on a repeated character. See
// todo.md.
export class Typeahead {
  constructor() {
    this.buffer = ""
    this.timer = null
  }

  search(character, items) {
    clearTimeout(this.timer)
    this.buffer += character.toLowerCase()
    this.timer = setTimeout(() => (this.buffer = ""), 1000)

    return items.find((item) =>
      item.textContent.trim().toLowerCase().startsWith(this.buffer)
    )
  }
}
