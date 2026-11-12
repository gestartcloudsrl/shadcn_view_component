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
                     "prototypes", "groupLabel", "announcer", "preferencesDialog", "preferencesForm",
                     "preferencesLimit" ]

  static values = {
    // The saved-view preferences, drawn by the server when a host asks for
    // them: the mode, the current set's key, where it is remembered, whether to
    // go there on arrival, and every set's URL.
    preferences: String,
    preferencesCurrent: String,
    preferencesStorage: String,
    preferencesRestore: Boolean,
    preferencesUrls: Object,
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
    eventCount: Object,
    moveLabels: Object
  }

  // The server ships only what cannot be worked out — see `#portable_events`
  // — so this fills the rest back in, once, rather than at every one of the
  // several thousand places that read an event.
  eventsValueChanged() {
    // Guarded on the attribute rather than on the parsed value, because this
    // runs twice for every write the controller makes: once from the call
    // below `this.eventsValue = …`, which has to be synchronous so the focus
    // can land on a cell that exists, and once when the attribute observer
    // catches up. A month can hold two thousand events; drawing it twice for
    // one move is the thing this compare is for.
    const source = this.eventsAttribute
    if (source === this.eventsSource) return

    this.eventsSource = source
    this.events = this.eventsValue.map((event) => ({
      ...event,
      to: event.to || event.from,
      allDay: !!event.allDay,
      meta: event.meta || event.time || ""
    }))
    this.index = null

    // The value is the source of truth, so a change to it *is* a redraw — and
    // on a morph this is the only thing that draws the server's answer.
    // `turbo:morph` fires before the attribute observer does, so the resync in
    // `index.js` renders the events from before the morph; without this, a
    // refusal — which sends back the payload the page already had — would never
    // reach the screen and the browser would go on drawing a move the server
    // threw away.
    if (this.weekPrototype) this.render()
  }

  // Stimulus's own naming, through its own identifier: reading the raw string
  // is what makes the guard above cheap.
  get eventsAttribute() {
    return this.element.getAttribute(`data-${this.identifier}-events-value`)
  }

  connect() {
    this.restorePreferences()

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

    // A row's faces, read once rather than per clone. The prototype draws one
    // face past the cap, so the faces it shows *are* the cap — `AVATARS_CAP`
    // stays in Ruby. The first face carries a picture and a badge; the badges
    // are kept apart by status, because the two differ by a class and the
    // clone may not write one.
    const faces = rows[0].querySelectorAll("[data-slot='avatar']")
    this.avatarCap = faces.length
    this.facePrototype = faces[0]
    this.badgePrototypes = Object.fromEntries(
      [ ...rows[0].querySelectorAll("[data-slot='avatar-badge']") ].map((badge) => [ badge.dataset.status, badge ])
    )
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

  // The saved view: a dialog asking the panel's questions for next time.
  //
  // The server drew every question and every option, each with the context
  // tokens it applies in (`data-preferences-when`), and in `:local` mode the
  // URL of every complete set it offers. So nothing here knows which question
  // follows which: it reads two answers, works out the context, and shows what
  // the tokens say. Saving is one `FormData` turned into the same key
  // `Preferences.key` spells, looked up in that map.

  // On a bare arrival — which only the host can recognise, so it says so with
  // `restore:` — go to the stored set, unless it is the one already drawn
  // (that would reload forever) or one the host no longer offers (there is no
  // URL for it, and a guessed one could be anything). A browser that refuses
  // storage is a browser with nothing stored.
  //
  // "Already drawn" is only a loop guard if the host's URL draws exactly the
  // set it was handed. One that drops a key, or an action that ignores one,
  // lands on a page with another current set — and, where the host's
  // `restore:` is true there too, asks again on every load. So each attempt
  // is marked in `sessionStorage` first: arriving with the mark still set
  // means the host was asked once and drew something else, and the mark is
  // spent instead of a second redirect. Where the mark cannot be written,
  // nothing is risked.
  restorePreferences() {
    if (this.preferencesValue !== "local") return

    const mark = `${this.preferencesStorageValue}:restoring`
    let attempted
    try {
      attempted = sessionStorage.getItem(mark)
      // Landed where it was sent: the next bare arrival may restore again.
      if (attempted && attempted === this.preferencesCurrentValue) {
        sessionStorage.removeItem(mark)
        attempted = null
      }
    } catch {
      return
    }
    if (!this.preferencesRestoreValue) return

    let key
    try {
      key = localStorage.getItem(this.preferencesStorageValue)
    } catch {
      return
    }
    if (!key || key === this.preferencesCurrentValue) return

    const url = this.preferenceUrl(key)
    if (!url || url === location.pathname + location.search) return

    try {
      if (attempted === key) {
        sessionStorage.removeItem(mark)
        return
      }
      sessionStorage.setItem(mark, key)
    } catch {
      return
    }

    location.replace(url)
  }

  // Every answer starts at what is drawn now, not at what was left in the form
  // by the last time it was opened and cancelled.
  openPreferences() {
    if (!this.hasPreferencesDialogTarget) return

    this.resetPreferences()
    this.preferencesDialog?.open()
    this.refinePreferences()
  }

  get preferencesDialog() {
    return this.application.getControllerForElementAndIdentifier(this.preferencesDialogTarget, "shadcn--dialog")
  }

  resetPreferences() {
    const current = new URLSearchParams(this.preferencesCurrentValue)

    for (const [ name, value ] of current) {
      if (this.hasPreferencesLimitTarget && name === this.preferencesLimitTarget.name) {
        this.resetPreferenceLimit(value)
        continue
      }

      const input = this.preferencesFormTarget.querySelector(`input[name="${CSS.escape(name)}"]`)
      if (input) this.choosePreference(input, value)
    }
  }

  // The chip limit is two fields under one name: "all" chooses the radio, a
  // number chooses "at most" and goes in the field. With "all" drawn, the field
  // goes back to the number the server put in it, the reading's own limit.
  resetPreferenceLimit(value) {
    const field = this.preferencesLimitTarget
    const group = field.closest("[role=radiogroup]")
    const input = group?.querySelector("[data-shadcn--radio-group-target=input]")
    if (!input) return

    const all = value === "all"
    field.value = all ? field.defaultValue : value
    this.choosePreference(input, all ? "all" : "number")
  }

  // Up to three passes, because each answer can move the next: Monthly brings
  // back the view, the view decides whether grouping is asked. Three is the
  // depth of the table — period, then view or showing, then the rest.
  refinePreferences() {
    if (!this.hasPreferencesFormTarget) return

    const form = this.preferencesFormTarget

    for (let pass = 0; pass < 3; pass++) {
      const context = this.preferencesContext(form)

      // Document order, so a question is settled before the options inside it
      // and an option can never come back on inside a question that is gone.
      for (const field of form.querySelectorAll("[data-preferences-when]")) {
        const tokens = field.dataset.preferencesWhen.split(/\s+/)
        const applies = tokens.some((token) => context.has(token)) &&
          !field.parentElement.closest("[data-preferences-when][hidden]")

        field.hidden = !applies
        // The buttons too, not only the input that submits: a hidden radio
        // left enabled is still one an arrow key walks onto.
        field.querySelectorAll("input, button").forEach((control) => { control.disabled = !applies })
      }

      this.namePreferenceGroups(form)
      if (!this.settlePreferences(form)) break
    }

    this.limitPreferences(form)
  }

  // The chip limit submits one value: the group's hidden input says "all", the
  // number field says how many, and only the chosen one is enabled. Both stay
  // off while the question itself is not asked — the pass above has already
  // disabled them, and this only ever turns one of them back off.
  limitPreferences(form) {
    for (const group of form.querySelectorAll("[role=radiogroup][data-preferences-limit]")) {
      const input = group.querySelector("[data-shadcn--radio-group-target=input]")
      const field = group.querySelector("input[type=number]")
      if (!input || !field || group.closest("[data-preferences-when][hidden]")) continue

      const typed = input.value === "number"
      input.disabled = typed
      field.disabled = !typed
    }
  }

  // What the period and its second answer say, as the tokens `Preferences`
  // writes: the period, and `period:view` (or `daily:showing`).
  preferencesContext(form) {
    const answer = (question) => form.querySelector(`input[name="preferences[${question}]"]`)?.value
    const period = answer("period")
    const second = period === "daily" ? answer("showing") : answer("view")

    return new Set([ "always", period, `${period}:${second}` ])
  }

  // A question still asked whose answer was just switched off — Grid, with the
  // period now Weekly — takes its first option that is still on. Returns
  // whether anything moved, which is what earns another pass.
  settlePreferences(form) {
    let moved = false

    for (const group of form.querySelectorAll("[role=radiogroup]")) {
      // The group's own input, not the first field inside it: the chip limit's
      // number field sits in the group too.
      const input = group.querySelector("[data-shadcn--radio-group-target=input]")
      if (!input?.name.startsWith("preferences[") || input.disabled) continue

      const items = [ ...group.querySelectorAll("[role=radio]") ]
      const chosen = items.find((item) => item.dataset.value === input.value)
      if (chosen && !chosen.disabled) continue

      const first = items.find((item) => !item.disabled)
      if (!first) continue

      this.choosePreference(input, first.dataset.value)
      moved = true
    }

    return moved
  }

  // Through the group's own controller rather than a click, because a click
  // moves the focus — onto a question the person was not answering.
  choosePreference(input, value) {
    const group = input.closest("[role=radiogroup]")
    const radios = group && this.application.getControllerForElementAndIdentifier(group, "shadcn--radio-group")
    if (!radios) return

    radios.valueValue = value
    radios.render()
  }

  // A group named by a heading that is now hidden is a group with no name.
  // The view has one heading per period; the group's `aria-labelledby` moves
  // to whichever of them is showing, found by the id prefix they share with
  // it rather than by spelling the ids here.
  namePreferenceGroups(form) {
    for (const group of form.querySelectorAll("[role=radiogroup][aria-labelledby]")) {
      const current = document.getElementById(group.getAttribute("aria-labelledby"))
      if (!current?.hidden) continue

      const prefix = current.id.slice(0, current.id.lastIndexOf("-") + 1)
      const heading = [ ...current.parentElement.children ]
        .find((element) => element !== current && element.id.startsWith(prefix) && !element.hidden)
      if (heading) group.setAttribute("aria-labelledby", heading.id)
    }
  }

  // `:local` only; in `:host` mode this action is not bound and the form goes
  // to the host as a form. Only the `preferences[…]` fields make the key: a
  // host's form also carries `_method` and the authenticity token. Storage
  // that refuses is a preference not remembered, and Save still goes there.
  savePreferences(event) {
    if (this.preferencesValue !== "local") return

    event.preventDefault()

    const key = [ ...new FormData(this.preferencesFormTarget) ]
      .filter(([ name ]) => name.startsWith("preferences["))
      .map(([ name, value ]) => `${name}=${value}`)
      .join("&")

    try {
      localStorage.setItem(this.preferencesStorageValue, key)
    } catch {
      // Nothing to do: the view is still the one asked for.
    }

    const url = this.preferenceUrl(key)
    if (url) {
      location.assign(url)
    } else {
      this.preferencesDialog?.close()
    }
  }

  // A set's URL from the server's map. A typed number has no entry of its own:
  // its set is listed with "#" in the number's place, and the URL as the two
  // halves the number goes between — or as one URL, where the host's never
  // carries the number. Which answer is the number is not known here; any
  // all-digit answer is tried.
  preferenceUrl(key) {
    const urls = this.preferencesUrlsValue
    if (typeof urls[key] === "string") return urls[key]

    const pairs = key.split("&")
    for (const [ index, pair ] of pairs.entries()) {
      const [ name, value ] = pair.split("=")
      if (!/^\d+$/.test(value ?? "")) continue

      const template = urls[pairs.map((other, at) => (at === index ? `${name}=#` : other)).join("&")]
      if (Array.isArray(template)) return template.join(value)
      if (typeof template === "string") return template
    }
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

    if (this.pickedId && event.key === " ") {
      event.preventDefault()
      this.place(from)
      return
    }
    if (this.pickedId && event.key === "Escape") {
      event.preventDefault()
      this.cancelPick()
      return
    }

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

  // --- moving an event ------------------------------------------------------
  //
  // The agenda is the one place an event is an element. The bars carry
  // `aria-hidden`, because the agenda reads the day out in full and that is
  // what earns them the right to be decoration — so a tab stop on a bar is an
  // `aria-hidden-focus` violation rather than a design choice. It costs
  // nothing: a crossing event is one *row* in the agenda where it is a bar per
  // week on the grid, so picking there never has to ask which object was meant.

  agendaKeydown(event) {
    if (!this.movableValue || event.key !== " ") return

    const row = event.target.closest("[data-slot='event-calendar-agenda-item']")
    if (!row) return

    event.preventDefault()
    this.pickedId = row.dataset.eventId
    this.announce("picked", this.events.find((candidate) => candidate.id === this.pickedId))
    // The day the pick was made *from*, which is the agenda's own — and the day
    // the focus is about to land on. The distance the arrows travel is then the
    // distance the event travels, which is the only rule a person can hold: a
    // three-day event picked from its middle and nudged once moves one day, not
    // three. Against the event's start instead, one press of → moved
    // 19–21 to 21–23, and that is the version this began as.
    this.pickedFrom = this.selectedValue
    this.render()
    this.focusDay(parse(this.selectedValue))
  }

  place(day) {
    const shift = this.offsetOf(day, parse(this.pickedFrom))
    const id = this.pickedId

    this.pickedId = null
    if (!shift) return this.redrawAt(day)

    this.moveEvent(id, shift, day)
  }

  // Both reads happen before the clear, and the row is found again after the
  // redraw: `render` rebuilds the agenda, so an element held across it is a
  // node nobody can see any more.
  cancelPick() {
    const id = this.pickedId
    const picked = this.events.find((event) => event.id === id)

    this.pickedId = null
    this.render()
    this.announce("returned", picked, picked.from)

    const row = this.element.querySelector(
      `[data-slot='event-calendar-agenda-item'][data-event-id='${id}']`
    )

    // The link, when the row is one: a row with a url has no stop of its own,
    // and focusing the `<li>` would quietly put the focus nowhere.
    if (row) (row.querySelector("a[href]") || row).focus()
    else this.focusDay(parse(picked.from))
  }

  // The value, assigned — not `this.events`, mutated behind it. That is what
  // lets a morph correct the browser without the host's help, and it is the
  // thing the design got wrong first: an optimistic move that mutates the copy
  // never touches the attribute, so a morph carrying the server's *original*
  // payload back is not a change, and a refusal never arrives.
  moveEvent(id, shift, focusOn) {
    const before = this.eventsValue
    const after = before.map((event) => (
      event.id === id
        ? {
            ...event,
            from: iso(addDays(parse(event.from), shift)),
            to: iso(addDays(parse(event.to || event.from), shift)),
            pending: true
          }
        : event
    ))
    const moved = after.find((event) => event.id === id)

    this.writeEvents(after, focusOn)
    this.announce("moved", moved, moved.from)

    this.dispatch("event-move", {
      detail: {
        id,
        from: moved.from,
        to: moved.to,
        // The half the library can own, since the only thing that knows where
        // the event was is this. The host decides *when* — a refusal answered
        // with a toast alone never redraws the calendar, and then nothing else
        // would put it back.
        revert: () => {
          const was = before.find((event) => event.id === id)

          this.writeEvents(before, was.from)
          this.announce("returned", was, was.from)
        }
      }
    })
  }

  writeEvents(events, focusOn) {
    this.eventsValue = events
    // The attribute observer is a microtask, and the focus below needs a cell
    // that exists now.
    this.eventsValueChanged()
    this.focusDay(parse(focusOn))
  }

  redrawAt(day) {
    this.render()
    this.focusDay(parse(day))
  }

  // Into a region of the move's own. The title is the calendar's other
  // `role="status"` and the month lives there — writing a sentence into it
  // would take the month off the page until the next navigation put it back.
  announce(key, event, day) {
    if (!this.hasAnnouncerTarget) return

    this.announcerTarget.textContent = (this.moveLabelsValue[key] || "")
      .replace("%{title}", event.title)
      .replace("%{date}", day ? this.format(parse(day), this.agendaFormatValue) : "")
  }

  // --- and the pointer's half of it -----------------------------------------

  // A grip rather than the whole bar. With the bar grabbable the day underneath
  // lost the centre of 17 of the 27 days that had events, and clicking one
  // stopped working at all — the layer stays `pointer-events-none`, so only
  // what the grip is standing on is taken from the day.
  //
  // The shift comes from the day *under the grip*, because a bar is clipped to
  // its week: an event crossing a Sunday has two of them, and the second one's
  // grip is on a Monday that is not the event's start.
  grab(event) {
    if (!this.movableValue) return

    const chip = event.currentTarget.closest("[data-slot='event-calendar-event']")
    const from = this.dayUnder(event.clientX, event.clientY)
    if (!chip || !from) return

    this.startDrag(event, chip.dataset.eventId, from, chip)
  }

  // The row's grip is its colour bar. It is nowhere on the grid, so it is
  // relative to the day the agenda is showing — the rule the keyboard follows,
  // and for the same reason.
  grabRow(event) {
    if (!this.movableValue) return

    const row = event.currentTarget.closest("[data-slot='event-calendar-agenda-item']")
    if (!row) return

    this.startDrag(event, row.dataset.eventId, this.selectedValue, row)
  }

  startDrag(event, id, from, marked) {
    const handle = event.currentTarget

    event.preventDefault()
    handle.setPointerCapture(event.pointerId)

    this.drag = { id, from, handle }
    this.mark(marked, "picked", true)

    this.onDrop = (dropped) => this.drop(dropped)
    handle.addEventListener("pointerup", this.onDrop)
    handle.addEventListener("pointercancel", this.onDrop)
  }

  drop(event) {
    const { id, from, handle } = this.drag

    handle.removeEventListener("pointerup", this.onDrop)
    handle.removeEventListener("pointercancel", this.onDrop)
    this.drag = null

    // A cancel is not a drop. The browser sends one when it takes the gesture
    // over — a scroll it decided was a scroll, a system gesture — and the
    // pointer's last position is then wherever it happened to be rather than
    // anywhere anybody chose. It is also the one branch here no spec can reach:
    // Selenium cannot cancel a pointer, and a synthetic `pointercancel` cannot
    // be preceded by a `setPointerCapture` that does not throw.
    const over = event.type === "pointercancel"
      ? from
      : (this.dayUnder(event.clientX, event.clientY) || from)
    const shift = this.offsetOf(over, parse(from))

    if (!shift) return this.redrawAt(over)

    this.moveEvent(id, shift, over)
  }

  // The bars sit in a `pointer-events-none` layer over the days, so the day is
  // *behind* whatever the pointer is on. `elementsFromPoint` gives the stack
  // rather than the top of it, which is the only way to read through a grip.
  dayUnder(x, y) {
    return document.elementsFromPoint(x, y)
                   .find((element) => element.dataset?.slot === "event-calendar-day")
                   ?.dataset?.day
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
    // A colour outside the palette — a host's own — ranks last, as
    // `COLOR_RANK.fetch(…, COLORS_END)` has it; `indexOf` alone put it first.
    const rank = (color) => {
      const index = this.colorsValue.indexOf(color)
      return index === -1 ? this.colorsValue.length : index
    }
    // Every host colour is `"host"`, so the property it names is the second
    // key and half of what a band is — `Component#in_bands` and `#same_band?`.
    // `<` rather than `localeCompare`, to order the names the way Ruby's
    // string comparison does.
    const property = (event) => event.colorProperty || ""
    const byProperty = (left, right) => {
      if (property(left) === property(right)) return 0
      return property(left) < property(right) ? -1 : 1
    }
    const marks = [ ...events ].sort((left, right) => rank(left.color) - rank(right.color) || byProperty(left, right))
    const band = (other, event) => other.color === event.color && property(other) === property(event)

    ticks.replaceChildren(...marks.map((event, index) => {
      const tick = this.tickPrototype.cloneNode(true)

      this.paint(tick, event)
      this.mark(tick, "runBefore", index > 0 && band(marks[index - 1], event))
      this.mark(tick, "runAfter", index + 1 < marks.length && band(marks[index + 1], event))

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

    this.paint(node, event)
    if (this.movableValue) node.dataset.eventId = event.id
    this.mark(node, "picked", event.id === this.pickedId)
    this.mark(node, "pending", !!event.pending)
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

  // `Component#agenda_row`, filled from the payload. The prototype holds every
  // part a row can have, so each one is filled or removed — never built.
  agendaElement(event) {
    const node = (event.url ? this.agendaLinkPrototype : this.agendaItemPrototype).cloneNode(true)
    const description = node.querySelector("[data-slot='event-calendar-agenda-description']")

    this.paint(node, event)
    if (this.movableValue) node.dataset.eventId = event.id
    this.mark(node, "picked", event.id === this.pickedId)
    if (event.url) this.link(node.querySelector("a"), event)
    this.fillTitle(node.querySelector("[data-slot='item-title']"), event)
    node.querySelector("[data-slot='item-description']").textContent = event.meta
    if (event.description) description.textContent = event.description
    else description.remove()
    this.fillFaces(node.querySelector("[data-slot='event-calendar-agenda-avatars']"), event.assignees)

    return node
  }

  // `Component#agenda_link`'s precedence: the host's attributes, then `href`
  // and `data-slot`, which are the row's. `class`, `data-action` and
  // `data-controller` join
  // rather than replace — and the classes are the host's own, written in the
  // host's source where its Tailwind saw them, so this adds none of its own.
  link(anchor, event) {
    Object.entries(event.attributes || {}).forEach(([ name, value ]) => {
      if (name === "href" || name === "data-slot") return

      if (name === "class") anchor.classList.add(...value.split(/\s+/).filter(Boolean))
      else if (name === "data-action" || name === "data-controller") {
        anchor.setAttribute(name, [ anchor.getAttribute(name), value ].filter(Boolean).join(" "))
      } else anchor.setAttribute(name, value)
    })
    anchor.setAttribute("href", event.url)
  }

  // `Component#agenda_title`: the title, then whichever of the subtitle and the
  // two flags the event has, a space apart. Plain text when it has none.
  fillTitle(title, event) {
    const subtitle = title.querySelector("[data-slot='event-calendar-agenda-subtitle']")
    const done = title.querySelector("[data-slot='event-calendar-agenda-done']")
    const attachment = title.querySelector("[data-slot='event-calendar-agenda-attachment']")
    const extras = [ event.subtitle && subtitle, event.done && done, event.attachment && attachment ].filter(Boolean)

    if (event.subtitle) subtitle.textContent = event.subtitle
    this.say(done, event.doneLabel)
    this.say(attachment, event.attachmentLabel)
    title.replaceChildren(event.title, ...extras.flatMap((part) => [ " ", part ]))
  }

  // `Faces#flag_icon` and `#assignee_badge`: what a screen reader hears is the
  // host's `label:` when it gave one, and the gem's word the prototype already
  // carries otherwise. Text, so the host's words are never markup.
  say(part, label) {
    if (label) part.querySelector(".sr-only").textContent = label
  }

  // `Faces#chip_avatars`: up to the cap, then the count.
  fillFaces(wrapper, assignees) {
    if (!assignees?.length) return wrapper.remove()

    const group = wrapper.querySelector("[data-slot='avatar-group']")
    const count = group.querySelector("[data-slot='avatar-group-count']")
    const shown = assignees.slice(0, this.avatarCap)
    const rest = assignees.length - shown.length

    // The `+` is the server's literal too — `Faces#avatars_more` writes it
    // untranslated — so this is the same string rather than text of its own.
    count.textContent = `+${rest}`
    group.replaceChildren(...shown.map((assignee) => this.faceElement(assignee)), ...(rest > 0 ? [ count ] : []))
  }

  // `Faces#avatar_for`. The picture's controller goes with the picture: an
  // initials-only face carries none on the server either.
  faceElement(assignee) {
    const face = this.facePrototype.cloneNode(true)
    const image = face.querySelector("[data-slot='avatar-image']")

    face.querySelector("[data-slot='avatar-badge']")?.remove()
    face.querySelector("[data-slot='avatar-fallback']").textContent = assignee.initials
    if (assignee.image) image.setAttribute("src", assignee.image)
    else {
      image.remove()
      face.removeAttribute("data-controller")
    }

    const badge = this.badgePrototypes[assignee.status]?.cloneNode(true)
    if (badge) {
      this.say(badge, assignee.label)
      face.append(badge)
    }

    return face
  }

  // `Component#color_style`, on a clone. A host colour is the two properties
  // the `data-color` rules set for a fixed one, inline so it beats them; the
  // ink is `--foreground` because no readable pair can be derived from a
  // colour the gem cannot see. A fixed colour takes neither, so nothing a
  // clone might have carried survives into it.
  paint(node, event) {
    node.dataset.color = event.color

    if (event.colorProperty) {
      node.style.setProperty("--event-color", `var(${event.colorProperty})`)
      node.style.setProperty("--event-ink", "var(--foreground)")
    } else {
      node.style.removeProperty("--event-color")
      node.style.removeProperty("--event-ink")
    }
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
