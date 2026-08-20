// The theming store — the port of what `next-themes` does for shadcn's own
// site, plus the colour-theme switching from its `ActiveThemeProvider`.
//
// Two independent axes, exactly as upstream:
//
//   mode   "light" | "dark" | "system"  → toggles `.dark` on <html>
//   theme  a palette name               → swaps `theme-*` on <body>
//
// Both are kept in `localStorage` and mirrored into a cookie, so a Rails layout
// can render the right classes server-side and avoid a flash without relying on
// the inline script.

export const MODE_STORAGE_KEY = "shadcn-ui-mode"
export const THEME_STORAGE_KEY = "shadcn-ui-theme"
export const CHANGE_EVENT = "shadcn:theme-change"

export const MODES = [ "light", "dark", "system" ]

const DARK_QUERY = "(prefers-color-scheme: dark)"

function read(key, fallback) {
  try {
    return window.localStorage.getItem(key) || fallback
  } catch {
    // Private browsing, or storage disabled.
    return fallback
  }
}

function write(key, value) {
  try {
    window.localStorage.setItem(key, value)
  } catch {
    // Ignore: the cookie mirror below is enough to survive a reload.
  }

  document.cookie = `${key}=${encodeURIComponent(value)}; path=/; max-age=31536000; samesite=lax`
}

export function systemMode() {
  return window.matchMedia(DARK_QUERY).matches ? "dark" : "light"
}

export function getMode() {
  const mode = read(MODE_STORAGE_KEY, "system")
  return MODES.includes(mode) ? mode : "system"
}

// The mode actually in effect: `system` resolved against the OS preference.
export function resolvedMode() {
  const mode = getMode()
  return mode === "system" ? systemMode() : mode
}

export function setMode(mode) {
  if (!MODES.includes(mode)) return

  write(MODE_STORAGE_KEY, mode)
  applyMode()
  announce()
}

export function toggleMode() {
  setMode(resolvedMode() === "dark" ? "light" : "dark")
}

// The palette in effect: what the visitor chose, or what the *document* says.
//
// The fallback used to be the literal "neutral", and that threw away the
// server's answer. `shadcn_theme_script_tag` writes the theme the page was
// rendered with onto `<html>` (`data-shadcn-theme`), and a host that sets
// `shadcn_theme_class(default: "sky")` renders `<body class="theme-sky">` — and
// then `applyTheme()` ran, found nothing in storage, and swapped the class back
// to `theme-neutral` on the first paint. The palette a host had chosen was
// visible only until the JavaScript booted, with nothing to explain it.
//
// Reading the document keeps one source of truth: the script tag has already
// resolved storage against the host's default, so this returns the same value
// when the visitor has chosen, and the host's when they have not.
export function getTheme() {
  return read(THEME_STORAGE_KEY, documentTheme())
}

// Two places a host publishes it, and the rendered class comes first.
//
// The class is what the **server** decided, reading the cookie this module
// mirrors every choice into and falling back to the host's own default. The
// attribute is what the script tag decided a moment later, reading
// `localStorage` against the same default. They agree whenever both are
// present — the cookie is the mirror of the storage — and where they differ the
// class is the better informed of the two: storage cleared with the cookie
// still there is a visitor whose choice the server can still see and the script
// cannot.
function documentTheme() {
  const target = document.body || document.documentElement
  const rendered = Array.from(target.classList).find((name) =>
    name.startsWith("theme-")
  )
  if (rendered) return rendered.slice("theme-".length)

  return document.documentElement.dataset.shadcnTheme || "neutral"
}

export function setTheme(theme) {
  if (!theme) return

  write(THEME_STORAGE_KEY, theme)
  applyTheme()
  announce()
}

export function applyMode() {
  const root = document.documentElement

  root.classList.toggle("dark", resolvedMode() === "dark")
  root.style.colorScheme = resolvedMode()
}

export function applyTheme() {
  const target = document.body
  if (!target) return

  // Resolved **before** the classes come off. `getTheme()` falls back to what
  // the document already says, and the loop below is what erases the answer:
  // asking afterwards read a body with no `theme-*` left on it, and every boot
  // fell back to the default no matter what the server had rendered.
  const theme = getTheme()

  for (const name of Array.from(target.classList)) {
    if (name.startsWith("theme-")) target.classList.remove(name)
  }
  target.classList.add(`theme-${theme}`)
}

export function apply() {
  applyMode()
  applyTheme()
}

function announce() {
  document.dispatchEvent(
    new CustomEvent(CHANGE_EVENT, {
      detail: { mode: getMode(), resolvedMode: resolvedMode(), theme: getTheme() }
    })
  )
}

// Follow the OS while the mode is "system", like next-themes does.
let watching = false

export function watchSystem() {
  if (watching) return
  watching = true

  window.matchMedia(DARK_QUERY).addEventListener("change", () => {
    if (getMode() !== "system") return

    applyMode()
    announce()
  })
}
