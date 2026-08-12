// Port of the positioning half of Radix's Popper.
//
// Radix wraps floating content in a fixed-position element carrying
// `data-radix-popper-content-wrapper` and publishes a set of CSS custom
// properties that the shadcn Tailwind classes read directly — e.g.
// `origin-(--radix-popover-content-transform-origin)` and
// `max-h-(--radix-select-content-available-height)`. Those names have to match
// exactly, so `prefix` names the component the variables belong to.

const SIDES = [ "top", "right", "bottom", "left" ]

const OPPOSITE = { top: "bottom", bottom: "top", left: "right", right: "left" }

export function createWrapper() {
  const wrapper = document.createElement("div")
  wrapper.setAttribute("data-radix-popper-content-wrapper", "")
  Object.assign(wrapper.style, {
    position: "fixed",
    left: "0",
    top: "0",
    minWidth: "max-content",
    zIndex: "50"
  })
  return wrapper
}

function measure(anchor) {
  const rect = anchor.getBoundingClientRect()
  return {
    top: rect.top,
    left: rect.left,
    right: rect.right,
    bottom: rect.bottom,
    width: rect.width,
    height: rect.height
  }
}

function place(side, align, anchorRect, size, sideOffset, alignOffset) {
  let x
  let y

  switch (side) {
    case "top":
      y = anchorRect.top - size.height - sideOffset
      break
    case "bottom":
      y = anchorRect.bottom + sideOffset
      break
    case "left":
      x = anchorRect.left - size.width - sideOffset
      break
    case "right":
      x = anchorRect.right + sideOffset
      break
  }

  const vertical = side === "top" || side === "bottom"

  if (vertical) {
    if (align === "start") x = anchorRect.left + alignOffset
    else if (align === "end") x = anchorRect.right - size.width - alignOffset
    else x = anchorRect.left + anchorRect.width / 2 - size.width / 2 + alignOffset
  } else {
    if (align === "start") y = anchorRect.top + alignOffset
    else if (align === "end") y = anchorRect.bottom - size.height - alignOffset
    else y = anchorRect.top + anchorRect.height / 2 - size.height / 2 + alignOffset
  }

  return { x, y }
}

function fits(side, anchorRect, size, sideOffset, padding, viewport) {
  switch (side) {
    case "top":
      return anchorRect.top - size.height - sideOffset >= padding
    case "bottom":
      return anchorRect.bottom + size.height + sideOffset <= viewport.height - padding
    case "left":
      return anchorRect.left - size.width - sideOffset >= padding
    case "right":
      return anchorRect.right + size.width + sideOffset <= viewport.width - padding
  }
  return true
}

function availableSpace(side, anchorRect, sideOffset, padding, viewport) {
  switch (side) {
    case "top":
      return anchorRect.top - sideOffset - padding
    case "bottom":
      return viewport.height - anchorRect.bottom - sideOffset - padding
    case "left":
      return anchorRect.left - sideOffset - padding
    case "right":
      return viewport.width - anchorRect.right - sideOffset - padding
  }
  return 0
}

// Positions `content` (already inside a wrapper from `createWrapper`) relative
// to `anchor`, flipping and shifting to stay on screen. Returns the resolved
// side and align, which callers mirror onto `data-side` / `data-align`.
// Radix places the arrow itself, through Popper: a wrapper pinned to the side
// the content ended up on, offset along the cross axis so it points at the
// anchor's middle (vendor's `@radix-ui/react-popper`, measured on the live
// tooltip on 2026-08-12 — `position:absolute; bottom:0; transform:translateY(100%);
// left:43.5px` for a tooltip placed on top).
//
// The tooltip's content renders the same two elements Radix does — a bare
// wrapper and, inside it, the rotated square shadcn styles — because the
// styling classes set `rotate` and `translate`, which are their own CSS
// properties in Tailwind v4 and compose with `transform` rather than losing to
// it. Placement written on the same element fights them; on the wrapper it does
// not. Without any of this the arrow is laid out in the text flow after the
// label: rendered, never seen, which is how it shipped.
// Radix's own, verbatim: the wrapper is pinned to the edge opposite the side
// the content took, and each side turns it so the same square points outwards.
const ARROW_TRANSFORM = {
  top: "translateY(100%)",
  bottom: "rotate(180deg)",
  left: "translateY(50%) rotate(-90deg) translateX(50%)",
  right: "translateY(50%) rotate(90deg) translateX(-50%)"
}

// One origin per side, and they are not decoration: three of these transforms
// rotate, and a rotation is only as right as the point it turns about. A single
// origin for all four — which is what this had, and what put the left and right
// arrows somewhere nobody could see them — spins two of them off their own edge.
const ARROW_ORIGIN = {
  top: "",
  right: "0 0",
  bottom: "center 0",
  left: "100% 0"
}

function placeArrow(arrow, side, anchorRect, size, wrapperX, wrapperY) {
  const width = arrow.offsetWidth || 10
  const height = arrow.offsetHeight || 10
  const vertical = side === "top" || side === "bottom"
  const padding = 6

  Object.assign(arrow.style, {
    position: "absolute",
    top: "", right: "", bottom: "", left: "",
    transform: ARROW_TRANSFORM[side],
    transformOrigin: ARROW_ORIGIN[side]
  })

  if (vertical) {
    const centre = anchorRect.left + anchorRect.width / 2 - wrapperX - width / 2
    arrow.style.left = `${Math.round(Math.min(Math.max(padding, centre), Math.max(padding, size.width - width - padding)))}px`
    arrow.style[side === "top" ? "bottom" : "top"] = "0px"
  } else {
    const centre = anchorRect.top + anchorRect.height / 2 - wrapperY - height / 2
    arrow.style.top = `${Math.round(Math.min(Math.max(padding, centre), Math.max(padding, size.height - height - padding)))}px`
    arrow.style[side === "left" ? "right" : "left"] = "0px"
  }
}

export function position(anchor, content, options = {}) {
  const {
    side = "bottom",
    align = "center",
    sideOffset = 0,
    alignOffset = 0,
    collisionPadding = 8,
    prefix = "popper",
    matchAnchorWidth = false
  } = options

  const wrapper = content.parentElement
  const viewport = { width: window.innerWidth, height: window.innerHeight }
  const anchorRect = measure(anchor)

  // An arrow has to fit between the panel and what it points at, so its height
  // is part of the offset rather than something to subtract later — Radix does
  // the same, `offset({ mainAxis: sideOffset + arrowHeight })` in
  // `@radix-ui/react-popper`. Which is why a tooltip whose `sideOffset` is 0,
  // as shadcn's is (tooltip.tsx:47), still stands clear of its trigger: without
  // this the panel sits flush and the arrow lies across the thing it came from.
  const arrow = content.querySelector("[data-slot$='-arrow']")
  const offset = sideOffset + (arrow ? arrow.offsetHeight : 0)

  if (matchAnchorWidth) content.style.minWidth = `${anchorRect.width}px`

  // Measure without a stale transform in the way.
  wrapper.style.transform = "translate(0, 0)"
  const size = { width: content.offsetWidth, height: content.offsetHeight }

  let resolvedSide = side
  if (!fits(side, anchorRect, size, offset, collisionPadding, viewport)) {
    const flipped = OPPOSITE[side]
    if (fits(flipped, anchorRect, size, offset, collisionPadding, viewport)) {
      resolvedSide = flipped
    } else {
      // Neither fits: take whichever has more room.
      resolvedSide =
        availableSpace(flipped, anchorRect, offset, collisionPadding, viewport) >
        availableSpace(side, anchorRect, offset, collisionPadding, viewport)
          ? flipped
          : side
    }
  }

  let { x, y } = place(resolvedSide, align, anchorRect, size, offset, alignOffset)

  // Shift back into the viewport along the cross axis.
  const maxX = viewport.width - size.width - collisionPadding
  const maxY = viewport.height - size.height - collisionPadding
  x = Math.min(Math.max(collisionPadding, x), Math.max(collisionPadding, maxX))
  y = Math.min(Math.max(collisionPadding, y), Math.max(collisionPadding, maxY))

  wrapper.style.transform = `translate(${Math.round(x)}px, ${Math.round(y)}px)`

  const available = availableSpace(resolvedSide, anchorRect, offset, collisionPadding, viewport)
  const originX = resolvedSide === "left" ? "100%" : resolvedSide === "right" ? "0%" : "50%"
  const originY = resolvedSide === "top" ? "100%" : resolvedSide === "bottom" ? "0%" : "50%"
  const transformOrigin = `${originX} ${originY}`

  const vars = {
    [`--radix-${prefix}-content-transform-origin`]: transformOrigin,
    [`--radix-${prefix}-content-available-width`]: `${viewport.width - collisionPadding * 2}px`,
    [`--radix-${prefix}-content-available-height`]: `${Math.max(0, available)}px`,
    "--radix-popper-transform-origin": transformOrigin,
    "--radix-popper-available-width": `${viewport.width - collisionPadding * 2}px`,
    "--radix-popper-available-height": `${Math.max(0, available)}px`,
    "--radix-popper-anchor-width": `${anchorRect.width}px`,
    "--radix-popper-anchor-height": `${anchorRect.height}px`,
    [`--radix-${prefix}-trigger-width`]: `${anchorRect.width}px`,
    [`--radix-${prefix}-trigger-height`]: `${anchorRect.height}px`
  }

  for (const [ name, value ] of Object.entries(vars)) {
    content.style.setProperty(name, value)
    wrapper.style.setProperty(name, value)
  }

  content.dataset.side = resolvedSide
  content.dataset.align = align

  if (arrow) placeArrow(arrow, resolvedSide, anchorRect, size, x, y)

  return { side: resolvedSide, align }
}

export { SIDES }
