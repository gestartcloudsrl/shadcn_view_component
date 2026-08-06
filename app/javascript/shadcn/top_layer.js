// Promotes floating content to the browser's top layer.
//
// `position: fixed` escapes overflow clipping but never escapes a *stacking
// context*: a layer's `z-50` is scoped to the nearest positioned ancestor with a
// z-index, so a `sticky z-40` header, an `isolate` card or anything with
// `opacity < 1` can bury it. No z-index can fix that from the inside.
//
// The Popover API does. `showPopover()` paints the element above every stacking
// context while leaving it exactly where it is in the DOM — which is what makes
// it usable here, since moving it would unbind the Stimulus actions on the close
// buttons and menu items.
//
// `manual` rather than `auto`: `auto` brings its own light-dismiss and its own
// nesting stack, which would fight the layer stack in `dismiss.js`.

export const SUPPORTED =
  typeof HTMLElement !== "undefined" && Object.hasOwn(HTMLElement.prototype, "popover")

// Older browsers keep the previous behaviour: still `position: fixed`, still
// correct in the common case, just vulnerable to a stacking context above it.
const usable = (element) => SUPPORTED && !!element

export function enable(element) {
  if (!usable(element)) return false

  element.popover = "manual"
  return true
}

export function show(element) {
  if (!usable(element) || !element.popover) return false

  // Throws if it is already showing, or not connected yet.
  try { element.showPopover() } catch { /* already open */ }
  return true
}

export function hide(element) {
  if (!usable(element) || !element.popover) return false

  try { element.hidePopover() } catch { /* already closed */ }
  return true
}
