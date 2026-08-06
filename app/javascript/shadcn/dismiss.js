// Port of Radix's DismissableLayer.
//
// Layers form a stack. Escape only closes the topmost one; a pointer press
// outside a layer closes it and everything above it. Elements registered as
// "anchors" (the trigger that opened the layer) do not count as outside, so a
// click on the trigger toggles rather than close-then-reopen.

const layers = []
let listening = false

function topLayer() {
  return layers[layers.length - 1]
}

function isInside(layer, target) {
  if (!target) return false
  if (layer.element.contains(target)) return true
  return layer.anchors.some((anchor) => anchor && anchor.contains(target))
}

function onPointerDown(event) {
  // Close from the top down, stopping at the first layer that owns the target.
  for (let i = layers.length - 1; i >= 0; i--) {
    const layer = layers[i]
    if (isInside(layer, event.target)) break
    layer.onDismiss({ reason: "pointerdown", originalEvent: event })
  }
}

function onKeyDown(event) {
  if (event.key !== "Escape") return

  const layer = topLayer()
  if (!layer) return

  layer.onDismiss({ reason: "escape", originalEvent: event })
}

function startListening() {
  if (listening) return
  // Capture phase so a layer closes before the click reaches the page.
  document.addEventListener("pointerdown", onPointerDown, true)
  // Escape listens on the bubble phase, and deliberately does not stop
  // propagation: a capture-phase `stopPropagation` here would swallow Escape
  // for the whole document — including the host application's own handlers —
  // whenever any layer, even a tooltip, happened to be open.
  document.addEventListener("keydown", onKeyDown)
  listening = true
}

function stopListening() {
  if (!listening) return
  document.removeEventListener("pointerdown", onPointerDown, true)
  document.removeEventListener("keydown", onKeyDown)
  listening = false
}

export function pushLayer({ element, anchors = [], onDismiss }) {
  const layer = { element, anchors: [].concat(anchors), onDismiss }
  layers.push(layer)
  startListening()
  return layer
}

export function removeLayer(layer) {
  const index = layers.indexOf(layer)
  if (index !== -1) layers.splice(index, 1)
  if (layers.length === 0) stopListening()
}

export function isTopLayer(layer) {
  return topLayer() === layer
}
