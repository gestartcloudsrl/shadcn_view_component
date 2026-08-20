import { Controller } from "@hotwired/stimulus"
import { addDays, iso, parse, shiftMonths, strftime } from "shadcn/dates"

// The month the server drew, moved.
//
// It is written to the two rules `calendar_controller.js` is written to, and
// for the same reason — the grid exists twice, in Ruby and here, and only a
// discipline keeps the two from drifting:
//
// 1. **No text of its own.** Month names, weekday names and the patterns they
//    are arranged in arrive as values. Times never arrive as patterns at all:
//    the server formats every one of them and ships the finished string with
//    the event, because `%p` and `%l` are a second locale implementation and
//    `shadcn/dates.js` deliberately stops at dates.
// 2. **No class of its own.** Every shape it builds is cloned from a
//    `<template>` the component rendered, so Tailwind — which scans Ruby and
//    not this file — has already seen every class that can appear. What it sets
//    instead are `data-*` attributes the Ruby styles with `data-[…]:` variants,
//    and two grid line numbers, which are what `col-start-3` compiles to.
//
// Lane packing is the one piece of logic that genuinely exists on both sides:
// `Schedule#pack` and `segmentsIn` below are the same algorithm, and they have
// to agree or a bar lands in a different row after you press ›. The server's is
// the one with the tests; this one is kept identical on purpose, down to
// "lowest free lane" rather than "next free lane".
export default class extends Controller {
  static targets = [ "title", "weeks", "agendaTitle", "agendaList", "agendaEmpty", "prototypes" ]

  static values = {
    month: String,
    // The application's today, not the browser's — `Time.zone` and a laptop's
    // clock disagree by a day for a few hours out of every twenty-four, and the
    // server has already drawn a cell from its own.
    today: String,
    selected: String,
    weekStartsOn: { type: Number, default: 1 },
    maxEvents: { type: Number, default: 3 },
    events: Array,
    locale: String,
    dayNames: Array,
    shortDayNames: Array,
    monthNames: Array,
    shortMonthNames: Array,
    monthFormat: String,
    dayFormat: String,
    agendaFormat: String,
    dayLabel: String,
    moreLabel: String,
    eventCount: Object
  }

  connect() {
    const shapes = this.prototypesTarget.content

    this.weekPrototype = shapes.querySelector("[data-slot='event-calendar-week']")
    this.eventPrototype = shapes.querySelector("[data-slot='event-calendar-event']")
    this.dotsPrototype = shapes.querySelector("[data-slot='event-calendar-day-dots']")
    this.dotPrototype = this.dotsPrototype.querySelector("[data-slot='event-calendar-day-dot']")
    this.morePrototype = shapes.querySelector("[data-slot='event-calendar-day-more']")

    // Two, because an event with a `url` is a link and one without is not, and
    // a clone cannot change its own tag name.
    const rows = shapes.querySelectorAll("[data-slot='event-calendar-agenda-item']")
    this.agendaItemPrototype = rows[0]
    this.agendaLinkPrototype = rows[1]

    // `Intl.PluralRules` rather than a two-branch ternary: the count is one the
    // server never saw, and "one or other" is wrong in every language with a
    // few and a many. A locale the browser does not know throws, and falling
    // back to its own is better than failing to draw the month.
    try {
      this.plurals = new Intl.PluralRules(this.localeValue)
    } catch {
      this.plurals = new Intl.PluralRules()
    }
  }

  // --- navigation -----------------------------------------------------------

  previous(event) {
    event.preventDefault()
    this.goTo(shiftMonths(this.month, -1))
  }

  next(event) {
    event.preventDefault()
    this.goTo(shiftMonths(this.month, 1))
  }

  today(event) {
    event.preventDefault()
    this.goTo(shiftMonths(parse(this.todayValue), 0), this.todayValue)
  }

  select(event) {
    const day = event.currentTarget.dataset.day
    if (!day) return

    this.selectedValue = day
    this.markSelection()
    this.renderAgenda()
    this.dispatch("select", { detail: { date: day, events: this.eventsOn(day) } })
  }

  // `month-change` is the hook a host needs and this component cannot provide:
  // the events it was given are the ones the server had, and the month you
  // navigate to may have others. Listening for it and replacing the component
  // over Turbo is the whole of lazy loading here.
  goTo(first, selected) {
    this.monthValue = iso(first)
    this.selectedValue = selected || this.defaultSelection(first)
    this.render()
    this.dispatch("month-change", { detail: { month: this.monthValue, selected: this.selectedValue } })
  }

  // The same rule `Component#default_selection` follows: today when today is in
  // view, and the first of the month otherwise.
  defaultSelection(first) {
    const today = parse(this.todayValue)
    const sameMonth = today.getFullYear() === first.getFullYear() && today.getMonth() === first.getMonth()

    return sameMonth ? this.todayValue : iso(first)
  }

  // --- drawing --------------------------------------------------------------

  render() {
    const first = this.month

    this.overflowed = false
    this.titleTarget.textContent = this.format(first, this.monthFormatValue)
    this.weeksTarget.replaceChildren(...this.weeksOf(first).map((days) => this.weekElement(days, first)))
    // After the weeks, because it is `weekElement` that finds out: a month
    // whose cells all fit gets its row back, and one that does not reserves it.
    this.mark(this.element, "overflow", this.overflowed)
    this.renderAgenda()
  }

  weekElement(days, first) {
    const week = this.weekPrototype.cloneNode(true)
    const cells = week.querySelectorAll("[data-slot='event-calendar-day']")
    const layer = week.querySelector("[data-slot='event-calendar-segments']")
    const segments = this.segmentsIn(days)

    if (segments.some((segment) => segment.lane > this.maxEventsValue)) this.overflowed = true

    days.forEach((day, index) => this.fillDay(cells[index], day, index + 1, segments, first))
    layer.replaceChildren(
      ...segments.filter((segment) => segment.lane <= this.maxEventsValue)
                 .map((segment) => this.eventElement(segment))
    )

    return week
  }

  fillDay(cell, day, column, segments, first) {
    const value = iso(day)
    const on = this.eventsOn(value)
    const selected = value === this.selectedValue
    const today = value === this.todayValue

    cell.dataset.day = value
    this.mark(cell, "today", today)
    this.mark(cell, "selected", selected)
    this.mark(cell, "outside", day.getMonth() !== first.getMonth())
    cell.setAttribute("aria-pressed", String(selected))
    if (today) cell.setAttribute("aria-current", "date")
    else cell.removeAttribute("aria-current")
    cell.setAttribute("aria-label", this.dayLabelFor(day, on.length))
    cell.querySelector("[data-slot='event-calendar-day-number']").textContent = String(day.getDate())

    // The prototype cell carries neither, so this appends rather than replaces
    // — and the cell is a fresh clone every render, so there is nothing left
    // over from the month before.
    if (on.length) cell.append(this.dotsElement(on))

    const hidden = segments.filter((segment) => segment.lane > this.maxEventsValue &&
                                                column >= segment.column &&
                                                column < segment.column + segment.span).length
    if (hidden) cell.append(this.moreElement(hidden))
  }

  dotsElement(events) {
    const dots = this.dotsPrototype.cloneNode(false)

    dots.replaceChildren(...events.slice(0, this.maxEventsValue).map((event) => {
      const dot = this.dotPrototype.cloneNode(true)
      dot.dataset.color = event.color

      return dot
    }))

    return dots
  }

  moreElement(count) {
    const more = this.morePrototype.cloneNode(true)
    more.textContent = this.moreLabelValue.replace("%{count}", String(count))

    return more
  }

  eventElement(segment) {
    const node = this.eventPrototype.cloneNode(true)
    const { event } = segment
    const dot = node.querySelector("[data-slot='event-calendar-event-dot']")
    const time = node.querySelector("[data-slot='event-calendar-event-time']")

    node.dataset.color = event.color
    node.style.gridColumn = `${segment.column} / span ${segment.span}`
    node.style.gridRow = String(segment.lane)
    this.mark(node, "continuesBefore", segment.continuesBefore)
    this.mark(node, "continuesAfter", segment.continuesAfter)
    node.setAttribute("title", event.title)

    if (event.allDay) dot.remove()
    if (event.time) time.textContent = event.time
    else time.remove()
    node.querySelector("[data-slot='event-calendar-event-title']").textContent = event.title

    return node
  }

  renderAgenda() {
    const on = this.eventsOn(this.selectedValue)

    this.agendaTitleTarget.textContent = this.format(parse(this.selectedValue), this.agendaFormatValue)
    this.agendaListTarget.replaceChildren(...on.map((event) => this.agendaElement(event)))
    this.agendaEmptyTarget.hidden = on.length > 0
  }

  agendaElement(event) {
    const node = (event.url ? this.agendaLinkPrototype : this.agendaItemPrototype).cloneNode(true)

    node.dataset.color = event.color
    if (event.url) node.querySelector("a").setAttribute("href", event.url)
    node.querySelector("[data-slot='event-calendar-agenda-event-title']").textContent = event.title
    node.querySelector("[data-slot='event-calendar-agenda-meta']").textContent = event.meta || ""

    return node
  }

  markSelection() {
    this.element.querySelectorAll("[data-slot='event-calendar-day']").forEach((cell) => {
      const chosen = cell.dataset.day === this.selectedValue

      this.mark(cell, "selected", chosen)
      cell.setAttribute("aria-pressed", String(chosen))
    })
  }

  // --- the grid, and what sits on it ----------------------------------------

  // `Calendar::Month#weeks` without `fixed_weeks`: back to the start of the
  // week the first falls in, forward to the end of the week the last falls in.
  weeksOf(first) {
    const last = new Date(first.getFullYear(), first.getMonth() + 1, 0)
    const end = addDays(last, this.mod(this.weekStartsOnValue - 1 - last.getDay()))
    const weeks = []
    let cursor = addDays(first, -this.mod(first.getDay() - this.weekStartsOnValue))

    while (cursor <= end) {
      const days = []

      for (let index = 0; index < 7; index += 1) {
        days.push(cursor)
        cursor = addDays(cursor, 1)
      }

      weeks.push(days)
    }

    return weeks
  }

  // `Schedule#pack`. The events arrive in the order the server packed them —
  // longest first, then all-day, then by the clock — so there is nothing to
  // sort here, and nothing that can be sorted differently.
  segmentsIn(days) {
    const first = iso(days[0])
    const last = iso(days[6])
    const occupied = []

    return this.eventsValue
      .filter((event) => event.from <= last && event.to >= first)
      .map((event) => {
        const column = Math.max(1, this.offsetOf(event.from, days[0]) + 1)
        const end = Math.min(7, this.offsetOf(event.to, days[0]) + 1)
        const lane = this.freeLane(occupied, column, end)

        if (!occupied[lane]) occupied[lane] = []
        occupied[lane].push([ column, end ])

        return {
          event,
          column,
          span: end - column + 1,
          lane: lane + 1,
          continuesBefore: event.from < first,
          continuesAfter: event.to > last
        }
      })
  }

  // Lowest free rather than next free, matching Ruby: it is what lets two
  // one-day events on opposite sides of the week share the top row instead of
  // stacking the second under the first.
  freeLane(occupied, from, to) {
    let lane = 0

    while (occupied[lane]?.some(([ start, end ]) => start <= to && end >= from)) lane += 1

    return lane
  }

  eventsOn(day) {
    return this.eventsValue
      .filter((event) => event.from <= day && event.to >= day)
      .sort((left, right) => left.dayOrder - right.dayOrder)
  }

  // --- helpers --------------------------------------------------------------

  get month() {
    return parse(this.monthValue)
  }

  mark(element, name, on) {
    if (on) element.dataset[name] = "true"
    else delete element.dataset[name]
  }

  mod(value) {
    return ((value % 7) + 7) % 7
  }

  // Rounded, because a day either side of a daylight-saving change is 23 or 25
  // hours long and the quotient is not an integer.
  offsetOf(day, from) {
    return Math.round((parse(day) - from) / 86400000)
  }

  dayLabelFor(day, count) {
    const date = this.format(day, this.dayFormatValue)
    if (count === 0) return date

    return this.dayLabelValue.replace("%{date}", date).replace("%{events}", this.eventCountFor(count))
  }

  eventCountFor(count) {
    const forms = this.eventCountValue
    const form = forms[this.plurals.select(count)] || forms.other || ""

    return form.replace("%{count}", String(count))
  }

  format(date, pattern) {
    return strftime(date, pattern, {
      dayNames: this.dayNamesValue,
      shortDayNames: this.shortDayNamesValue,
      monthNames: this.monthNamesValue,
      shortMonthNames: this.shortMonthNamesValue
    })
  }
}
