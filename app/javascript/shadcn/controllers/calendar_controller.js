import { Controller } from "@hotwired/stimulus"
import { readDirection } from "shadcn/direction"

// The calendar is rendered by the server — a month is a `<table>`, and Ruby
// builds it in `Calendar::Month`. This moves it: the nav, the two dropdowns and
// the grid's keyboard, plus the re-render each of those asks for.
//
// Which means the grid exists twice, and that is the one duplication this port
// introduces. Two rules keep it from drifting, and both are the reason the
// values below are as long as they are:
//
// 1. **No text of its own.** Month names, weekday names, the date format and
//    every label template come from the server, so `I18n` stays the only thing
//    that decides how a date reads. A `toLocaleDateString` here would answer to
//    the *browser's* locale, and the month you navigated to would be spelled
//    differently from the one you started on.
// 2. **No class of its own.** The modifier classes arrive as values. Tailwind
//    scans source text and does not read this file, and `parity_spec` reads the
//    Ruby, so a class written here would be both uncompiled and unchecked.
//
// What it does build is structure, and even that is cloned from what the server
// rendered rather than written out.
export default class extends Controller {
  static targets = [ "grid", "weeks", "caption", "previous", "next", "monthSelect", "yearSelect" ]

  static values = {
    month: String,
    weekStartsOn: { type: Number, default: 1 },
    fixedWeeks: Boolean,
    showOutsideDays: { type: Boolean, default: true },
    showWeekNumber: Boolean,
    startMonth: String,
    endMonth: String,
    mode: { type: String, default: "single" },
    selected: Array,
    disabled: Array,
    dayNames: Array,
    shortDayNames: Array,
    monthNames: Array,
    shortMonthNames: Array,
    dateFormat: String,
    monthFormat: String,
    todayLabel: String,
    selectedLabel: String,
    weekNumberLabel: String,
    todayClass: String,
    outsideClass: String,
    disabledClass: String,
    hiddenClass: String,
    rangeStartClass: String,
    rangeMiddleClass: String,
    rangeEndClass: String
  }

  connect() {
    this.direction = readDirection(this.element)
    // The prototypes for a re-render, taken from the server's own output: a
    // week row, and a cell with every modifier class stripped back off it. The
    // alternative is markup in a template literal here, which is the thing
    // rule 2 above is about.
    this.rowPrototype = this.weeksTarget.querySelector("tr").cloneNode(true)
    this.cellPrototype = this.plainCell()
    this.numberPrototype = this.showWeekNumberValue
      ? this.weeksTarget.querySelector("th").cloneNode(true)
      : null
  }

  previous(event) {
    event.preventDefault()
    this.goTo(this.shiftMonths(this.month, -1))
  }

  next(event) {
    event.preventDefault()
    this.goTo(this.shiftMonths(this.month, 1))
  }

  chooseMonth(event) {
    const month = this.month
    month.setMonth(Number(event.target.value) - 1)
    this.goTo(month)
  }

  chooseYear(event) {
    const year = this.month
    year.setFullYear(Number(event.target.value))
    this.goTo(year)
  }

  // The grid pattern: one day is tabbable and the arrows reach the rest. Radix
  // is not the reference here — `react-day-picker`'s own `DayPicker.js:176-190`
  // is, and it moves by day, by week, to the ends of the week, and by month or
  // year on Page keys.
  keydown(event) {
    const from = this.dayOf(event.target)
    if (!from) return

    const back = this.direction === "rtl" ? 1 : -1
    const moves = {
      ArrowLeft: [ "day", back ],
      ArrowRight: [ "day", -back ],
      ArrowUp: [ "week", -1 ],
      ArrowDown: [ "week", 1 ],
      Home: [ "weekStart", 0 ],
      End: [ "weekEnd", 0 ],
      PageUp: [ event.shiftKey ? "year" : "month", -1 ],
      PageDown: [ event.shiftKey ? "year" : "month", 1 ]
    }
    const move = moves[event.key]
    if (!move) return

    event.preventDefault()
    this.focusDay(this.step(from, ...move))
  }

  // A day that is focused becomes the tabbable one, so tabbing away and back
  // returns to where the reader was rather than to the top of the month.
  focused(event) {
    const day = this.dayOf(event.target)
    if (day) this.markFocusTarget(event.target)
  }

  get month() {
    return this.parse(this.monthValue)
  }

  // --- moving ---------------------------------------------------------------

  step(from, unit, by) {
    const to = new Date(from)

    if (unit === "day") to.setDate(to.getDate() + by)
    if (unit === "week") to.setDate(to.getDate() + by * 7)
    if (unit === "month") to.setMonth(to.getMonth() + by)
    if (unit === "year") to.setFullYear(to.getFullYear() + by)
    if (unit === "weekStart") to.setDate(to.getDate() - this.offsetInWeek(to))
    if (unit === "weekEnd") to.setDate(to.getDate() + (6 - this.offsetInWeek(to)))

    return this.clampToBounds(to)
  }

  // Focus follows the day even when the day is in another month — which is what
  // makes ArrowRight on the last of the month work at all. The month changes
  // under the focus, and the focus is restored once the new grid is there.
  focusDay(date) {
    const iso = this.iso(date)
    if (!this.inDisplayedMonth(date)) this.goTo(date)

    const button = this.buttonFor(iso)
    if (!button) return

    this.markFocusTarget(button)
    button.focus()
  }

  goTo(date) {
    const target = this.clampToBounds(date)
    const first = new Date(target.getFullYear(), target.getMonth(), 1)
    if (this.iso(first) === this.monthValue) return

    this.monthValue = this.iso(first)
    this.render()
    this.dispatch("month", { detail: { month: this.monthValue } })
  }

  // Compared as ISO text rather than as `Date`s: the bounds arrive as strings,
  // and `new Date("2026-01-01")` is parsed as UTC where `new Date(y, m, d)` is
  // local — a comparison between the two is off by a day for half the world.
  clampToBounds(date) {
    const iso = this.iso(date)

    if (this.startMonthValue && iso < this.startMonthValue) return this.parse(this.startMonthValue)
    if (this.endMonthValue && iso > this.endMonthValue) return this.parse(this.endMonthValue)

    return date
  }

  // --- rendering ------------------------------------------------------------

  render() {
    const rows = this.weeks()

    this.weeksTarget.replaceChildren(...rows.map((week) => this.row(week)))
    this.captionTarget.textContent = this.formatMonth(this.month)
    this.gridTarget.setAttribute("aria-label", this.formatMonth(this.month))
    this.updateNav()
    this.updateDropdowns()
    this.markInitialFocusTarget()
  }

  // The Ruby rule, repeated: the selected day if it is in this grid, otherwise
  // today, otherwise the first of the month — and never a disabled one. Without
  // it a navigated month has no tabbable day at all and the grid leaves the tab
  // order, which is how this first worked.
  markInitialFocusTarget() {
    const first = new Date(this.month.getFullYear(), this.month.getMonth(), 1)
    const candidates = [ ...this.selectedValue, this.iso(new Date()), this.iso(first) ]

    for (const iso of candidates) {
      const button = this.buttonFor(iso)
      if (button && !button.disabled) return this.markFocusTarget(button)
    }
  }

  // The same grid `Calendar::Month#weeks` builds, and it has to stay the same:
  // the first day of the week the month starts in, through the last day of the
  // week it ends in, six rows when a fixed height was asked for.
  weeks() {
    const first = new Date(this.month.getFullYear(), this.month.getMonth(), 1)
    const start = new Date(first)
    start.setDate(start.getDate() - this.offsetInWeek(first))

    const last = new Date(this.month.getFullYear(), this.month.getMonth() + 1, 0)
    const span = Math.round((last - start) / 86400000) + 1
    const rows = this.fixedWeeksValue ? 6 : Math.ceil(span / 7)

    return Array.from({ length: rows }, (_, row) =>
      Array.from({ length: 7 }, (_, column) => {
        const day = new Date(start)
        day.setDate(start.getDate() + row * 7 + column)
        return day
      }))
  }

  row(week) {
    const row = this.rowPrototype.cloneNode(false)

    if (this.numberPrototype) row.appendChild(this.weekNumber(week))
    for (const day of week) row.appendChild(this.cell(day))

    return row
  }

  weekNumber(week) {
    const cell = this.numberPrototype.cloneNode(true)
    const number = this.isoWeek(week[0])

    cell.querySelector("div").textContent = number
    cell.setAttribute("aria-label", this.weekNumberLabelValue.replace("%{number}", number))

    return cell
  }

  cell(day) {
    const cell = this.cellPrototype.cloneNode(true)
    const outside = day.getMonth() !== this.month.getMonth()
    const hidden = outside && !this.showOutsideDaysValue
    const selected = this.isSelected(day)
    const disabled = this.isDisabled(day)

    cell.className = [
      cell.className,
      this.isToday(day) && this.todayClassValue,
      outside && this.outsideClassValue,
      disabled && this.disabledClassValue,
      hidden && this.hiddenClassValue,
      this.isRangeStart(day) && this.rangeStartClassValue,
      this.isRangeMiddle(day) && this.rangeMiddleClassValue,
      this.isRangeEnd(day) && this.rangeEndClassValue
    ].filter(Boolean).join(" ")

    this.set(cell, "data-day", this.iso(day))
    this.set(cell, "data-month", outside ? this.iso(day).slice(0, 7) : null)
    this.set(cell, "data-outside", outside ? "true" : null)
    this.set(cell, "data-today", this.isToday(day) ? "true" : null)
    this.set(cell, "data-selected", selected ? "true" : null)
    this.set(cell, "data-disabled", disabled ? "true" : null)
    this.set(cell, "data-hidden", hidden ? "true" : null)
    this.set(cell, "aria-selected", selected ? "true" : null)

    const button = cell.querySelector("button")
    if (hidden) button.remove()
    else this.dayButton(button, day, { selected, disabled })

    return cell
  }

  dayButton(button, day, { selected, disabled }) {
    button.textContent = String(day.getDate())
    button.disabled = disabled
    button.tabIndex = -1
    this.set(button, "data-day", this.format(day, this.dateFormatValue))
    this.set(button, "aria-label", this.dayLabel(day, selected))
    this.set(button, "data-selected-single", this.modeValue === "single" && selected ? "true" : null)
    this.set(button, "data-range-start", this.isRangeStart(day) ? "true" : null)
    this.set(button, "data-range-middle", this.isRangeMiddle(day) ? "true" : null)
    this.set(button, "data-range-end", this.isRangeEnd(day) ? "true" : null)
  }

  // Exactly one button in the grid is tabbable: the selected day if it is in
  // this month, otherwise today, otherwise the first of the month.
  markFocusTarget(button) {
    for (const other of this.buttons) other.tabIndex = -1
    button.tabIndex = 0
  }

  updateNav() {
    const back = this.shiftMonths(this.month, -1)
    const forward = this.shiftMonths(this.month, 1)

    this.mark(this.previousTarget, this.outOfBounds(back))
    this.mark(this.nextTarget, this.outOfBounds(forward))
  }

  mark(button, unavailable) {
    this.set(button, "aria-disabled", unavailable ? "true" : null)
    this.set(button, "tabindex", unavailable ? "-1" : null)
  }

  // The dropdowns are the caption, so they follow it rather than lead it — a
  // month reached with the arrow keys has to leave them showing where it went.
  updateDropdowns() {
    if (this.hasMonthSelectTarget) {
      this.monthSelectTarget.value = String(this.month.getMonth() + 1)
      // The *short* name: the options the server rendered are the abbreviated
      // ones, and what is shown is the selected option's own label. Writing the
      // full name here made the two renderers disagree in the one place a
      // person is looking.
      this.label(this.monthSelectTarget, this.shortMonthNamesValue[this.month.getMonth()])
    }

    if (this.hasYearSelectTarget) {
      this.yearSelectTarget.value = String(this.month.getFullYear())
      this.label(this.yearSelectTarget, String(this.month.getFullYear()))
    }
  }

  // What is read is the `aria-hidden` span under the invisible select, so the
  // two have to be set together or the calendar says one month and shows
  // another.
  label(select, text) {
    const shown = select.parentElement.querySelector("[aria-hidden=true]")
    if (!shown?.firstChild) return

    shown.firstChild.textContent = text
  }

  // --- what a day is --------------------------------------------------------

  isToday(day) {
    return this.iso(day) === this.iso(new Date())
  }

  isSelected(day) {
    if (this.range) return this.iso(day) >= this.range.from && this.iso(day) <= this.range.to

    return this.selectedValue.includes(this.iso(day))
  }

  isRangeStart(day) { return Boolean(this.range) && this.iso(day) === this.range.from }
  isRangeEnd(day) { return Boolean(this.range) && this.iso(day) === this.range.to }

  isRangeMiddle(day) {
    return this.isSelected(day) && Boolean(this.range) && !this.isRangeStart(day) && !this.isRangeEnd(day)
  }

  get range() {
    return this.modeValue === "range" && this.selectedValue.length === 2
      ? { from: this.selectedValue[0], to: this.selectedValue[1] }
      : null
  }

  // A `disabled:` that is a Date or a Range crosses to the browser as itself. A
  // callable cannot, and does not: it decided the month the server rendered and
  // says nothing about the ones reached from here — see features/calendar.md.
  isDisabled(day) {
    const iso = this.iso(day)
    if (this.outOfBounds(day)) return true

    return this.disabledValue.some((matcher) =>
      typeof matcher === "string" ? matcher === iso : iso >= matcher.from && iso <= matcher.to)
  }

  // At the granularity the bounds are about: `start_month` and `end_month` name
  // months, so a day in the same month as the bound is inside it.
  outOfBounds(date) {
    const month = this.iso(date).slice(0, 7)

    return Boolean(this.startMonthValue && month < this.startMonthValue.slice(0, 7)) ||
      Boolean(this.endMonthValue && month > this.endMonthValue.slice(0, 7))
  }

  inDisplayedMonth(date) {
    return date.getFullYear() === this.month.getFullYear() && date.getMonth() === this.month.getMonth()
  }

  // --- reading the DOM ------------------------------------------------------

  get buttons() {
    return [ ...this.weeksTarget.querySelectorAll("button") ]
  }

  buttonFor(iso) {
    return this.weeksTarget.querySelector(`td[data-day="${iso}"] button`)
  }

  dayOf(element) {
    const cell = element.closest("td[data-day]")

    return cell ? this.parse(cell.dataset.day) : null
  }

  // A cell with the state stripped off it, which is what every later cell is
  // built from. Taken from a plain day rather than assembled: an outside or a
  // selected one would carry classes this then has to guess at removing.
  plainCell() {
    const plain = this.weeksTarget.querySelector(
      "td:not([data-today]):not([data-outside]):not([data-selected]):not([data-disabled])"
    )
    const cell = (plain || this.weeksTarget.querySelector("td")).cloneNode(true)

    for (const state of [ "day", "month", "outside", "today", "selected", "disabled", "hidden" ]) {
      delete cell.dataset[state]
    }
    cell.removeAttribute("aria-selected")

    return cell
  }

  set(element, name, value) {
    if (value === null || value === undefined || value === false) element.removeAttribute(name)
    else element.setAttribute(name, value)
  }

  // --- dates ----------------------------------------------------------------

  parse(iso) {
    const [ year, month, day ] = iso.split("-").map(Number)

    return new Date(year, month - 1, day)
  }

  shiftMonths(date, by) {
    return new Date(date.getFullYear(), date.getMonth() + by, 1)
  }

  offsetInWeek(date) {
    return (date.getDay() - this.weekStartsOnValue + 7) % 7
  }

  iso(date) {
    return [
      date.getFullYear(),
      String(date.getMonth() + 1).padStart(2, "0"),
      String(date.getDate()).padStart(2, "0")
    ].join("-")
  }

  // ISO-8601, matching `Date#cweek` on the Ruby side: the week holding the
  // Thursday of this week is the week of its year.
  isoWeek(date) {
    const thursday = new Date(date)
    thursday.setDate(thursday.getDate() + 3 - ((date.getDay() + 6) % 7))
    const first = new Date(thursday.getFullYear(), 0, 4)

    return 1 + Math.round(((thursday - first) / 86400000 - 3 + ((first.getDay() + 6) % 7)) / 7)
  }

  dayLabel(day, selected) {
    let label = this.format(day, this.dateFormatValue)
    if (this.isToday(day)) label = this.todayLabelValue.replace("%{date}", label)
    if (selected) label = this.selectedLabelValue.replace("%{date}", label)

    return label
  }

  formatMonth(date) {
    return this.format(date, this.monthFormatValue)
  }

  // Enough `strftime` to read the formats Rails' own locales are written in,
  // and no more. The pattern comes from `I18n` with the rest of the text, so a
  // host that has translated `date.formats.long` gets its own order and its own
  // punctuation here rather than this file's idea of them.
  format(date, pattern) {
    const day = date.getDate()
    const month = date.getMonth() + 1
    const tokens = {
      "%A": this.dayNamesValue[date.getDay()],
      "%a": this.shortDayNamesValue[date.getDay()],
      "%B": this.monthNamesValue[date.getMonth()],
      "%b": this.shortMonthNamesValue[date.getMonth()],
      "%d": String(day).padStart(2, "0"),
      "%-d": String(day),
      "%e": String(day).padStart(2, " "),
      "%m": String(month).padStart(2, "0"),
      "%-m": String(month),
      "%Y": String(date.getFullYear()),
      "%y": String(date.getFullYear()).slice(-2)
    }

    return pattern.replace(/%-?[A-Za-z]/g, (token) => (token in tokens ? tokens[token] : token))
  }
}
