import { Controller } from "@hotwired/stimulus"
import { commandScore } from "shadcn/command_score"
import { uniqueId } from "shadcn/id"

// The palette. Items are rendered by the server and this filters, ranks and
// walks them — which is what `cmdk` does, minus the part where it also owns the
// markup.
//
// Ranking rather than filtering is the difference between this and the
// searchable select, and it is deliberate: a select filters a list its caller
// ordered and keeps that order, while a palette answers "what did you mean" and
// has to put the answer first.
export default class extends Controller {
  static targets = [ "search", "list", "item", "group", "separator", "empty" ]

  connect() {
    // The order the server rendered, which is what an empty query goes back to.
    this.order = new Map(this.itemTargets.map((item, index) => [ item, index ]))
    this.select(this.visibleItems[0])
  }

  search() {
    const query = this.searchTarget.value.trim()

    for (const item of this.itemTargets) {
      const score = query === "" ? 1 : commandScore(this.textOf(item), query, this.keywordsOf(item))

      item.dataset.score = score
      item.hidden = score === 0
    }

    this.rank(query)
    this.settle()
  }

  // Within a group first, then the groups themselves by their best item: an
  // answer buried under a heading nobody is looking at is not an answer.
  rank(query) {
    for (const container of this.containers) {
      // `:scope >`, because the list holds the groups as well as any loose
      // items: without it every item in the document matched, and appending
      // them to the list pulled them out of the groups they belonged to.
      const items = [ ...container.querySelectorAll(":scope > [cmdk-item]") ]
      const sorted = query === ""
        ? items.sort((a, b) => this.order.get(a) - this.order.get(b))
        : items.sort((a, b) => this.scoreOf(b) - this.scoreOf(a) || this.order.get(a) - this.order.get(b))

      for (const item of sorted) container.appendChild(item)
    }

    if (this.groupTargets.length < 2) return

    const groups = [ ...this.groupTargets ].sort((a, b) =>
      query === "" ? this.order.get(this.firstOf(a)) - this.order.get(this.firstOf(b)) : this.bestOf(b) - this.bestOf(a))

    for (const group of groups) group.parentElement.appendChild(group)
  }

  // What is left showing decides the rest: an empty state, the groups that
  // still have something in them, and where the selection goes.
  settle() {
    for (const group of this.groupTargets) {
      group.hidden = [ ...group.querySelectorAll("[cmdk-item]") ].every((item) => item.hidden)
    }

    // A rule between two things is a rule between nothing once one of them has
    // gone.
    for (const separator of this.separatorTargets) {
      separator.hidden = this.groupTargets.length > 0 && this.groupTargets.every((group) => group.hidden)
    }

    const matches = this.visibleItems
    // The empty state lives *inside* the list — upstream's own example puts it
    // there — so hiding the list when nothing matches hides the message that
    // says nothing matches. The select hides its list because its empty state
    // is a sibling; this one is not.
    for (const empty of this.emptyTargets) empty.hidden = matches.length > 0

    this.select(matches.includes(this.selected) ? this.selected : matches[0])
  }

  keydown(event) {
    const keys = {
      ArrowDown: () => this.move(1),
      ArrowUp: () => this.move(-1),
      Home: () => this.select(this.visibleItems[0]),
      End: () => this.select(this.visibleItems.at(-1)),
      Enter: () => this.choose()
    }
    const move = keys[event.key]
    if (!move) return

    event.preventDefault()
    move()
  }

  // The pointer selects what it is over, as cmdk does — so the keyboard and the
  // pointer never disagree about which item Enter would take.
  hover(event) {
    this.select(event.currentTarget)
  }

  choose(event) {
    const item = event?.currentTarget ?? this.selected
    if (!item || item.dataset.disabled === "true") return

    this.select(item)
    this.dispatch("select", { detail: { value: this.valueOf(item), item } })
  }

  move(by) {
    const items = this.visibleItems
    if (items.length === 0) return

    const at = items.indexOf(this.selected)
    // Wrapping, which is cmdk's default (`loop` turns it off there, and the
    // palette is a ring: the first item is one press up from the last).
    this.select(items[(at + by + items.length) % items.length])
  }

  select(item) {
    for (const other of this.itemTargets) {
      const chosen = other === item

      other.setAttribute("aria-selected", String(chosen))
      other.dataset.selected = String(chosen)
    }

    this.selected = item
    this.publish(item)
    item?.scrollIntoView({ block: "nearest" })
  }

  // The virtual focus: the input keeps the caret and the list is walked by id,
  // which is the same arrangement the searchable select uses.
  publish(item) {
    for (const element of [ this.hasSearchTarget && this.searchTarget, this.hasListTarget && this.listTarget ]) {
      if (!element) continue

      if (item) {
        // As in the select and the combobox: the id is assigned where it is
        // read, so an item added after `connect` still has one to point at.
        item.id ||= uniqueId("shadcn-command-item")
        element.setAttribute("aria-activedescendant", item.id)
      }
      else element.removeAttribute("aria-activedescendant")
    }
  }

  get selected() {
    return this._selected
  }

  set selected(item) {
    this._selected = item
  }

  get visibleItems() {
    return this.itemTargets.filter((item) => !item.hidden && item.dataset.disabled !== "true" && !this.insideHiddenGroup(item))
  }

  insideHiddenGroup(item) {
    return this.groupTargets.some((group) => group.hidden && group.contains(item))
  }

  // Where items live: the wrapper inside each group, and the list itself for
  // the ones written outside a group.
  get containers() {
    const groups = this.groupTargets.map((group) => group.querySelector("[cmdk-group-items]") || group)

    return this.hasListTarget ? [ ...groups, this.listTarget ] : groups
  }

  firstOf(group) {
    return group.querySelector("[cmdk-item]")
  }

  bestOf(group) {
    return [ ...group.querySelectorAll("[cmdk-item]") ].reduce((best, item) => Math.max(best, this.scoreOf(item)), 0)
  }

  scoreOf(item) {
    return Number(item.dataset.score ?? 0)
  }

  // What is searched: the value a caller gave, otherwise the text a reader
  // sees — cmdk's own rule.
  textOf(item) {
    return item.dataset.value || item.textContent.trim().replace(/\s+/g, " ")
  }

  keywordsOf(item) {
    return (item.dataset.keywords || "").split(/\s+/).filter(Boolean)
  }

  valueOf(item) {
    return item.dataset.value || this.textOf(item)
  }
}
