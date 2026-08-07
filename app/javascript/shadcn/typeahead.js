// A one-second character buffer shared by any roving-focus list (menu items,
// select options): each keystroke is appended to the buffer, which clears
// itself after a second of silence, and the caller gets back the item to
// move the highlight to next, or nothing when there is nowhere new to move —
// ported from Radix's `findNextItem` (vendor/radix/ui/select.tsx:1906-1921),
// whose body is identical to the dropdown menu's own `getNextMatch`
// (vendor/radix/ui/menu.tsx:1336-1347), so the search starts at the item
// currently highlighted and wraps, rather than always scanning from the top
// of the list.
//
// The input differs in Radix's *menu*, not in the file above: `getNextMatch`
// is handed an array of label strings and the winner mapped back to an item
// (vendor/radix/ui/menu.tsx:451-454), so two items sharing a label are one
// candidate there and two here. `findNextItem`'s own callers pass items and
// compare by identity, exactly as this does. See `.claude/docs/todo.md`.
//
// Deliberately does not know how the caller moves focus — that stays in each
// controller, which owns its own item list and highlighting. The current
// item is a parameter rather than something read off the DOM here.
export class Typeahead {
  constructor() {
    this.buffer = ""
    this.timer = null
  }

  search(character, items, currentItem) {
    clearTimeout(this.timer)
    // Raw case, not lowercased: Radix compares the raw characters to decide
    // whether they repeat (select.tsx:1911) and only lowercases for the
    // `startsWith` match (select.tsx:1918) — "Bb" is not a repeat of "b".
    this.buffer += character
    this.timer = setTimeout(() => (this.buffer = ""), 1000)

    return findNextItem(items, this.buffer, currentItem)
  }
}

// This is the "meat" of the typeahead matching logic (vendor/radix/ui/select.tsx:1906-1921,
// vendor/radix/ui/menu.tsx:1336-1347). It takes a list of items, the search
// and the current item, and returns the next item (or `undefined`).
//
// The search is normalized because if a user has repeatedly pressed a
// character, we want the exact same behavior as if we only had that one
// character (ie. cycle through items starting with that character).
//
// The items are also reordered by wrapping the array around the current
// item, so we always look forward from the current item and picking the
// first match is always the correct one.
//
// Finally, if the normalized search is exactly one character, the current
// item is excluded from the candidates, because otherwise it would always be
// the first to match and focus would never move. This is as opposed to the
// regular case, where focus should stay put if the current item still
// matches.
function findNextItem(items, search, currentItem) {
  const isRepeated = search.length > 1 && Array.from(search).every((char) => char === search[0])
  const normalizedSearch = isRepeated ? search[0] : search
  const currentItemIndex = currentItem ? items.indexOf(currentItem) : -1
  let wrapped = wrapArray(items, Math.max(currentItemIndex, 0))

  if (normalizedSearch.length === 1) wrapped = wrapped.filter((item) => item !== currentItem)

  const nextItem = wrapped.find((item) =>
    item.textContent.trim().toLowerCase().startsWith(normalizedSearch.toLowerCase())
  )

  return nextItem !== currentItem ? nextItem : undefined
}

// Wraps an array around itself at a given start index
// (vendor/radix/ui/select.tsx:1923-1929).
// Example: `wrapArray([ "a", "b", "c", "d" ], 2)` is `[ "c", "d", "a", "b" ]`.
function wrapArray(array, startIndex) {
  return array.map((_, index) => array[(startIndex + index) % array.length])
}
