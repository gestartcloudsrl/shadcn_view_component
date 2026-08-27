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
  static targets = [ "title", "weeks", "agendaDate", "agendaCount", "agendaList", "agendaEmpty",
                     "prototypes", "groupLabel" ]

  static values = {
    month: String,
    // The application's today, not the browser's — `Time.zone` and a laptop's
    // clock disagree by a day for a few hours out of every twenty-four, and the
    // server has already drawn a cell from its own.
    today: String,
    selected: String,
    weekStartsOn: { type: Number, default: 1 },
    maxEvents: { type: Number, default: 3 },
    tickSizes: Array,
    denseAbove: Number,
    reading: String,
    // Whether this month may be redrawn here at all. A reading the server draws
    // whole ships no events and no prototypes, so there is nothing to draw
    // from. Crossed as a fact rather than derived from `reading`, because the
    // list of names that used to decide it went stale the first time a reading
    // was added.
    clientDrawn: { type: Boolean, default: true },
    // Whether this calendar's events can be moved. Crossed rather than derived,
    // for the reason `clientDrawn` is: it decides whether an identity is in the
    // DOM at all, and a controller guessing that would guess wrong on a
    // calendar a host has deliberately left read-only.
    movable: { type: Boolean, default: false },
    colors: Array,
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

  // The server ships only what cannot be worked out — see `#portable_events`
  // — so this fills the rest back in, once, rather than at every one of the
  // several thousand places that read an event.
  eventsValueChanged() {
    this.events = this.eventsValue.map((event) => ({
      ...event,
      to: event.to || event.from,
      allDay: !!event.allDay,
      meta: event.meta || event.time || ""
    }))
    this.index = null
  }

  connect() {
    // Only a reading that redraws ships shapes to redraw from. Workload, hours
    // and daily are drawn whole by the server and carry no `prototypes`
    // template — and this used to read it regardless, so `connect` threw on
    // every one of them.
    //
    // Nothing visibly broke, which is why it lasted: Stimulus catches the
    // throw, and `data-action` binds independently of `connect`, so the
    // keyboard, the selection and the month announce all still worked. What
    // shipped instead was a console error on every page a server-drawn reading
    // appears on, and a `this.plurals` left undefined for anything that later
    // wants it.
    if (this.hasPrototypesTarget) this.readPrototypes()

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

  readPrototypes() {
    const shapes = this.prototypesTarget.content

    this.weekPrototype = shapes.querySelector("[data-slot='event-calendar-week']")
    this.eventPrototype = shapes.querySelector("[data-slot='event-calendar-event']")
    this.ticksPrototype = shapes.querySelector("[data-slot='event-calendar-day-ticks']")
    this.tickPrototype = this.ticksPrototype.querySelector("[data-slot='event-calendar-day-tick']")
    this.morePrototype = shapes.querySelector("[data-slot='event-calendar-day-more']")

    // Two, because an event with a `url` is a link and one without is not, and
    // a clone cannot change its own tag name.
    const rows = shapes.querySelectorAll("[data-slot='event-calendar-agenda-item']")
    this.agendaItemPrototype = rows[0]
    this.agendaLinkPrototype = rows[1]
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

  // Which of the three views the month is drawn as. A view is a different
  // render — a different arrangement, or a different reading altogether — so
  // this announces the ask rather than answering it, and a host that gave
  // `view_url:` never gets here because the items are links.
  changeView(event) {
    const chosen = event.currentTarget.dataset.value
    if (!chosen) return

    this.dispatch("view", { detail: { view: chosen } })
  }

  // Which halves of a day are drawn — the axis, the list, or both. Different
  // markup again, so the server answers it and this only announces the ask.
  reshow(event) {
    const chosen = event.currentTarget.dataset.value
    if (!chosen) return

    this.dispatch("reshow", { detail: { showing: chosen } })
  }

  // A shape is different markup, so this is the server's to answer: it
  // announces the ask, and a host that gave `shape_url:` never gets here.
  reshape(event) {
    const chosen = event.currentTarget.dataset.value
    if (!chosen) return

    this.dispatch("reshape", { detail: { shape: chosen } })
  }

  // A cell renders the grouping it is showing, so there is nothing here to
  // swap: this announces the ask. A host that gave `group_url:` never gets
  // here — the menu items are links.
  regroup(event) {
    const chosen = event.currentTarget.dataset.value
    if (!chosen) return

    this.dispatch("regroup", { detail: { group: chosen } })
  }

  // The cap is the server's now, so there is nothing here to toggle: what a
  // cell renders is what it shows. This announces the ask, and a host that
  // gave `show_all_url:` never gets here — the toggle is a link.
  showAll(event) {
    const pressed = event.currentTarget.getAttribute("aria-pressed") === "true"

    this.dispatch("show-all", { detail: { showAll: !pressed } })
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

  // --- the selection, and the keyboard that moves it ------------------------

  // `aria-selected` present only when true, and the single tab stop travels
  // with it — the pair the gem's `Calendar` writes.
  markSelected(cell, chosen) {
    if (chosen) cell.setAttribute("aria-selected", "true")
    else cell.removeAttribute("aria-selected")
    cell.setAttribute("tabindex", chosen ? "0" : "-1")
  }

  markSelection() {
    this.element.querySelectorAll("[data-slot='event-calendar-day']").forEach((cell) => {
      const chosen = cell.dataset.day === this.selectedValue

      this.mark(cell, "selected", chosen)
      this.markSelected(cell, chosen)
    })
  }

  // `Calendar`'s own map, minus the year jump it has and the bounds it clamps
  // to. Without this the month was forty-two tab stops and no way across it.
  keydown(event) {
    const from = event.target.closest("[data-slot='event-calendar-day']")?.dataset?.day
    if (!from) return

    const moves = {
      ArrowLeft: [ "day", -1 ],
      ArrowRight: [ "day", 1 ],
      ArrowUp: [ "week", -1 ],
      ArrowDown: [ "week", 1 ],
      Home: [ "weekStart", 0 ],
      End: [ "weekEnd", 0 ],
      PageUp: [ "month", -1 ],
      PageDown: [ "month", 1 ]
    }
    const move = moves[event.key]
    if (!move) return

    event.preventDefault()
    this.focusDay(this.step(parse(from), ...move))
  }

  step(from, unit, by) {
    const to = new Date(from)

    if (unit === "day") to.setDate(to.getDate() + by)
    if (unit === "week") to.setDate(to.getDate() + by * 7)
    if (unit === "month") to.setMonth(to.getMonth() + by)
    if (unit === "weekStart") to.setDate(to.getDate() - this.mod(to.getDay() - this.weekStartsOnValue))
    if (unit === "weekEnd") to.setDate(to.getDate() + (6 - this.mod(to.getDay() - this.weekStartsOnValue)))

    return to
  }

  // A step off the edge of the grid is a month change. The workload reading is
  // server-drawn, so there it announces and stops rather than pretending to
  // move — the same boundary its nav buttons have.
  focusDay(date) {
    const day = iso(date)
    let cell = this.cellFor(day)

    if (!cell) {
      this.goTo(shiftMonths(date, 0), day)
      cell = this.cellFor(day)
      if (!cell) return
    }

    this.focusCell(cell)
  }

  cellFor(day) {
    return this.element.querySelector(`[data-slot='event-calendar-day'][data-day='${day}']`)
  }

  // The tab stop and the focus travel together — one cell is tabbable and it is
  // the one focused. Reached from two directions, which is why it is a method
  // rather than the tail of `focusDay`: the arrows move it, and `render` puts
  // it back after rebuilding the cell it was on.
  focusCell(cell) {
    this.element.querySelectorAll("[data-slot='event-calendar-day']")
        .forEach((other) => other.setAttribute("tabindex", other === cell ? "0" : "-1"))
    cell.focus()
  }

  // --- drawing --------------------------------------------------------------
  //
  // Everything above walks between months, selects a day and answers the
  // options panel; everything below redraws one, which only the events reading
  // ever does — the other three are drawn whole by the server and ship no
  // payload to redraw from. The order is the seam, and the order is all it is:
  // two files were tried, measured and dropped, and `.claude/docs/todo.md` has
  // what that cost and what would change the answer.
  //
  // Worth knowing before moving anything across the line: **it is crossed in
  // both directions**, which is why the two halves are an order and not two
  // classes. Down, `goTo` calls `render` and `select` calls `eventsOn` and
  // `renderAgenda` — so navigating and selecting, which every reading does,
  // run through code only one reading needs. Up, `fillDay` calls
  // `markSelected`. The three genuinely mutual helpers are at the foot of the
  // file, under their own heading, rather than pretending to belong to a side.


  render() {
    // The workload reading is server-drawn: its cells hold crews, clients and
    // a tinted count that `#portable_events` does not ship, so there is nothing
    // here to rebuild them from. Redrawing anyway is what filled September with
    // August's people. Until the payload carries them, `month-change` is the
    // whole of their navigation — see `goTo`.
    if (!this.clientDrawnValue) return

    // Every cell is replaced below, so the one holding the focus stops existing
    // and the focus falls to the body — and `fillDay` hands the roving tab stop
    // back to the *selected* day, which is not where the arrows left it.
    //
    // The keyboard's own path hides both: `focusDay` calls `goTo` and refocuses
    // afterwards. A `turbo:morph` resync has nothing to refocus with, so a
    // morph refresh of a page holding a client-drawn month sent the reader
    // back to the body — no drag and no navigation involved. Measured on
    // `/turbo-probe/one` with none of this file's other paths running.
    const focused = this.element.contains(document.activeElement)
      ? document.activeElement.closest("[data-slot='event-calendar-day']")?.dataset?.day
      : null

    const first = this.month
    const weeks = this.weeksOf(first)

    this.overflowed = false
    // Over the grid's own days, which is what `Schedule#busiest` counts — the
    // days either side of the month are cells too, and a size chosen from a
    // different set of them would change under the nav for no visible reason.
    this.measure(weeks.flat())
    this.titleTarget.textContent = this.format(first, this.monthFormatValue)
    this.weeksTarget.replaceChildren(...weeks.map((days) => this.weekElement(days, first)))
    // After the weeks, because it is `weekElement` that finds out: a month
    // whose cells all fit gets its row back, and one that does not reserves it.
    this.mark(this.element, "overflow", this.labelled && this.overflowed)
    this.renderAgenda()

    // Only when the day survived the redraw. A month stepped off the edge of
    // does not hold the cell that was focused, and there this is `goTo` running
    // inside `focusDay`, which is already on its way to the right one.
    const cell = focused && this.cellFor(focused)
    if (cell) this.focusCell(cell)
  }

  weekElement(days, first) {
    const week = this.weekPrototype.cloneNode(true)
    const cells = week.querySelectorAll("[data-slot='event-calendar-day']")
    const layer = week.querySelector("[data-slot='event-calendar-segments']")
    const segments = this.segmentsIn(days)

    if (segments.some((segment) => segment.lane > this.maxEventsValue)) this.overflowed = true

    days.forEach((day, index) => this.fillDay(cells[index], day, index + 1, segments, first))
    // Nothing goes in the layer when the calendar is dense — `Component#segments`
    // renders none either, and for the same reason: ninety-three bars drawn to
    // be hidden by a media query are ninety-three elements nobody will see.
    layer.replaceChildren(
      ...(this.labelled
        ? segments.filter((segment) => segment.lane <= this.maxEventsValue)
                  .map((segment) => this.eventElement(segment))
        : [])
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
    this.markSelected(cell, selected)
    if (today) cell.setAttribute("aria-current", "date")
    else cell.removeAttribute("aria-current")
    cell.setAttribute("aria-label", this.dayLabelFor(day, on.length))
    cell.querySelector("[data-slot='event-calendar-day-number']").textContent = String(day.getDate())

    // The prototype cell carries neither, so this appends rather than replaces
    // — and the cell is a fresh clone every render, so there is nothing left
    // over from the month before.
    if (on.length) cell.append(this.ticksElement(on))

    const hidden = segments.filter((segment) => segment.lane > this.maxEventsValue &&
                                                column >= segment.column &&
                                                column < segment.column + segment.span).length
    if (hidden && this.labelled) cell.append(this.moreElement(hidden))
  }

  // Every event, not the first few: below `sm` the marks are the only reading
  // there is, and a strip that stopped at three would be a count pretending to
  // be a picture.
  ticksElement(events) {
    const ticks = this.ticksPrototype.cloneNode(false)
    // `Component#in_bands`. `sort` is stable, so the clock still decides the
    // order inside a band, exactly as it does on the server.
    const marks = [ ...events ].sort((left, right) =>
      this.colorsValue.indexOf(left.color) - this.colorsValue.indexOf(right.color))

    ticks.replaceChildren(...marks.map((event, index) => {
      const tick = this.tickPrototype.cloneNode(true)

      tick.dataset.color = event.color
      this.mark(tick, "runBefore", index > 0 && marks[index - 1].color === event.color)
      this.mark(tick, "runAfter", index + 1 < marks.length && marks[index + 1].color === event.color)

      return tick
    }))

    return ticks
  }

  // Both answers the busiest day decides — how big a mark is, and whether this
  // month names its events at all — so they are found together and found again
  // for every month. The numbers cross from Ruby rather than the answers, for
  // the reason the plural forms do: they stay where Tailwind and the specs can
  // see them.
  measure(days) {
    const busiest = Math.max(0, ...days.map((day) => this.eventsOn(iso(day)).length))
    const [ , size ] = this.tickSizesValue.find(([ most ]) => most === null || busiest <= most)

    this.element.style.setProperty("--event-calendar-tick", size)
    // `Component#labelled?` is `reading == :auto && busiest <= DENSE_ABOVE`.
    // Dropping the first clause let a workload month acquire `data-labelled`
    // on its first re-render, which turns the bar layer on over the rows
    // layout and resizes every cell.
    this.labelled = this.readingValue === "auto" && busiest <= this.denseAboveValue
    this.mark(this.element, "labelled", this.labelled)
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
    if (this.movableValue) node.dataset.eventId = event.id
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
    // Server-owned when the cells are links: the component leaves the targets
    // off, and redrawing an agenda a frame is about to swap would be a race
    // with the network.
    if (!this.hasAgendaListTarget) return

    const on = this.eventsOn(this.selectedValue)

    this.agendaDateTarget.textContent = this.format(parse(this.selectedValue), this.agendaFormatValue)
    this.agendaCountTarget.textContent = on.length ? this.eventCountFor(on.length) : ""
    this.agendaListTarget.replaceChildren(...on.map((event) => this.agendaElement(event)))
    this.agendaEmptyTarget.hidden = on.length > 0
  }

  agendaElement(event) {
    const node = (event.url ? this.agendaLinkPrototype : this.agendaItemPrototype).cloneNode(true)

    node.dataset.color = event.color
    if (this.movableValue) node.dataset.eventId = event.id
    if (event.url) node.querySelector("a").setAttribute("href", event.url)
    node.querySelector("[data-slot='event-calendar-agenda-event-title']").textContent = event.title
    node.querySelector("[data-slot='event-calendar-agenda-meta']").textContent = event.meta

    return node
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
  // all-day first, then longest, then by the clock — so there is nothing to
  // sort here, and nothing that can be sorted differently. That the order is
  // the array's own is what makes `Event#sort_key` the single place it is
  // decided: change it there and this follows without being touched.
  segmentsIn(days) {
    const first = iso(days[0])
    const last = iso(days[6])
    const occupied = []

    return this.events
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

  // Indexed once, not filtered per cell. `Schedule#by_day`'s own comment
  // rejects the scan on the Ruby side and this file was doing it anyway:
  // eighty-five full passes of the whole array per navigation, each with a
  // sort, on a month that can hold two thousand events.
  eventsOn(day) {
    if (!this.index) this.buildIndex()

    return this.index.get(day) || []
  }

  buildIndex() {
    this.index = new Map()

    // Walked as dates and formatted once per day, not parsed back from the
    // string it just wrote: the old loop did `parse(iso(...))` every step, so a
    // job running a year paid three hundred and sixty-five round trips through
    // both.
    //
    // Not clipped to the month on screen, though it is tempting: the index is
    // built once per payload and `eventsValueChanged` is the only thing that
    // clears it, so it has to answer for every month this calendar can step to
    // without a request.
    for (const event of this.events) {
      const last = parse(event.to)

      for (let date = parse(event.from); date <= last; date = addDays(date, 1)) {
        const day = iso(date)

        if (!this.index.has(day)) this.index.set(day, [])
        this.index.get(day).push(event)
      }
    }
    this.index.forEach((list) => list.sort((left, right) => left.dayOrder - right.dayOrder))
  }

  // --- what the drawing needs to write a cell -------------------------------

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

  // --- what both halves need ------------------------------------------------

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
}
