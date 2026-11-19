// The date arithmetic and the date *spelling* the two calendar controllers
// share.
//
// Both of them re-render a month the server never drew, and both are written to
// the same rule: **no text of their own.** Month names, weekday names and the
// format they are arranged in come from `I18n` as controller values, because a
// `toLocaleDateString` here would answer to the browser's locale, and the month
// you navigated to would be spelled differently from the one you started on.
//
// That rule is what makes `strftime` below worth sharing rather than worth
// copying: it is the one function that turns the server's pattern into a
// string, and two of them would be two chances to disagree about what `%-d`
// means.

export function parse(iso) {
  const [ year, month, day ] = iso.split("-").map(Number)

  return new Date(year, month - 1, day)
}

export function iso(date) {
  return [
    date.getFullYear(),
    String(date.getMonth() + 1).padStart(2, "0"),
    String(date.getDate()).padStart(2, "0")
  ].join("-")
}

export function shiftMonths(date, by) {
  return new Date(date.getFullYear(), date.getMonth() + by, 1)
}

export function addDays(date, by) {
  const shifted = new Date(date)
  shifted.setDate(shifted.getDate() + by)

  return shifted
}

// Enough `strftime` to read the formats Rails' own locales are written in, and
// no more. The pattern comes from `I18n` with the rest of the text, so a host
// that has translated `date.formats.long` gets its own order and its own
// punctuation here rather than this file's idea of them.
//
// Deliberately date-only: `%H`, `%M` and `%p` are absent, and adding them would
// start a second locale implementation next to Ruby's. The component that shows
// times formats every one of them on the server and ships the finished string.
export function strftime(date, pattern, names) {
  const day = date.getDate()
  const month = date.getMonth() + 1
  const tokens = {
    "%A": names.dayNames[date.getDay()],
    "%a": names.shortDayNames[date.getDay()],
    "%B": names.monthNames[date.getMonth()],
    "%b": names.shortMonthNames[date.getMonth()],
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
