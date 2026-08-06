// Port of Radix's FocusScope: keep Tab inside a container while it is open and
// hand focus back to whatever had it when the container closes.

const FOCUSABLE = [
  "a[href]",
  "button:not([disabled])",
  "input:not([disabled]):not([type='hidden'])",
  "select:not([disabled])",
  "textarea:not([disabled])",
  "[tabindex]:not([tabindex='-1'])",
  "audio[controls]",
  "video[controls]",
  "[contenteditable]:not([contenteditable='false'])"
].join(",")

function isVisible(element) {
  return !!(element.offsetWidth || element.offsetHeight || element.getClientRects().length)
}

export function tabbable(container) {
  return Array.from(container.querySelectorAll(FOCUSABLE)).filter(
    (element) => !element.hasAttribute("disabled") && isVisible(element)
  )
}

export function focusFirst(container) {
  const candidates = tabbable(container)
  const target = candidates[0] || container
  target.focus({ preventScroll: true })
}

// Traps Tab/Shift+Tab inside `container`. Returns a function that releases the
// trap and restores focus to `restoreTo` (defaults to the previously focused
// element).
export function trapFocus(container, restoreTo = document.activeElement) {
  function onKeyDown(event) {
    if (event.key !== "Tab") return

    const candidates = tabbable(container)
    if (candidates.length === 0) {
      event.preventDefault()
      return
    }

    const first = candidates[0]
    const last = candidates[candidates.length - 1]

    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last.focus({ preventScroll: true })
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus({ preventScroll: true })
    }
  }

  container.addEventListener("keydown", onKeyDown)

  return function release() {
    container.removeEventListener("keydown", onKeyDown)
    if (restoreTo && document.contains(restoreTo)) {
      restoreTo.focus({ preventScroll: true })
    }
  }
}

// Radix locks body scrolling while a modal layer is open. Reference counted so
// nested layers behave.
let scrollLocks = 0
let previousOverflow = null

export function lockScroll() {
  if (scrollLocks === 0) {
    previousOverflow = document.body.style.overflow
    document.body.style.overflow = "hidden"
  }
  scrollLocks += 1
}

export function unlockScroll() {
  scrollLocks = Math.max(0, scrollLocks - 1)
  if (scrollLocks === 0) {
    document.body.style.overflow = previousOverflow || ""
    previousOverflow = null
  }
}
