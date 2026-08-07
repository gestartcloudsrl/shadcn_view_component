// A one-second character buffer shared by any roving-focus list (menu items,
// select options): each keystroke is appended to the buffer, which clears
// itself after a second of silence, and the caller gets back whichever item's
// text starts with the buffer so far.
//
// Deliberately does not know how the caller moves focus — wrapping at the
// ends versus clamping is a roving-focus decision, not a typeahead one, and
// stays in each controller.
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
