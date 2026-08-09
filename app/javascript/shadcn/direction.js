// Reading direction, for the controllers whose arrow keys depend on it.
//
// This is the port of shadcn's `direction.tsx`, and the port is a module rather
// than a component because there is nothing to render: upstream's
// `DirectionProvider` wraps Radix's, which is a React context and emits no DOM
// at all (vendor/shadcn/ui/direction.tsx). React needs that context because a
// component cannot easily read inherited DOM state while rendering. A Stimulus
// controller has no such problem — the browser has already resolved `dir` for
// every element by the time one runs.
//
// So a host writes `<html dir="rtl">`, or `dir` on any ancestor, and these
// controllers follow. There is no provider to mount and no value to thread
// through, which is the whole of what this component becomes here.

// `getComputedStyle().direction` rather than walking up looking for a `dir`
// attribute: it resolves inheritance, the CSS `direction` property, and
// `dir="auto"` — which has no fixed answer until the browser has looked at the
// text. Reading the attribute would get the first two wrong and the third
// impossible.
export function readDirection(element) {
  if (!element) return "ltr"

  return window.getComputedStyle(element).direction === "rtl" ? "rtl" : "ltr"
}

// Radix's `getDirectionAwareKey` (vendor/radix/ui/roving-focus-group.tsx:359).
// Right-to-left swaps the two horizontal arrows and nothing else — `ArrowUp`
// and `ArrowDown` are unaffected, because reading direction is horizontal and
// a column is a column either way.
//
// Applied *before* a key is mapped to an intent, never after: the point is that
// in RTL the key labelled Left is the one that means "next", so every caller
// can keep one map and translate the key on the way in.
export function directionAwareKey(key, direction) {
  if (direction !== "rtl") return key

  if (key === "ArrowLeft") return "ArrowRight"
  if (key === "ArrowRight") return "ArrowLeft"

  return key
}
