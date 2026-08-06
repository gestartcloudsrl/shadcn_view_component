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

export function getTheme() {
  return read(THEME_STORAGE_KEY, "neutral")
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

  for (const name of Array.from(target.classList)) {
    if (name.startsWith("theme-")) target.classList.remove(name)
  }
  target.classList.add(`theme-${getTheme()}`)
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
