// The measurements a message scroller runs on, ported from
// `vendor/shadcn-react/message-scroller/geometry.ts`.
//
// Every function here is pure: it reads rects, `scrollTop`, computed padding
// and two `data-` attributes, and returns a number, an element or null. Nothing
// writes, nothing schedules, nothing holds state — which is why this is a module
// of its own rather than methods on the controller, and why it can be tested
// without a browser opening anything.
//
// One function of upstream's is deliberately missing:
// `getMessageScrollerVisibilityState`, the largest in the file, which exists to
// feed `useMessageScrollerVisibility`. That surface is not reproduced — see
// `.claude/docs/features/message-scroller.md` for the measurement behind that
// decision. Nothing else in this file referenced it.

// Upstream's `EMPTY_MESSAGE_SCROLLER_SCROLLABLE` (types.ts:193). A frozen
// object rather than a fresh one per call, so a caller cannot mutate the answer
// for the next.
const NOT_SCROLLABLE = Object.freeze({ start: false, end: false })

// The rows, in document order. The spacer is a sibling of the items and has to
// be excluded by identity rather than by a selector: it carries no `data-slot`
// of its own, and upstream filters it the same way (geometry.ts:108-116).
export function getMessageScrollerItems(content, spacer) {
  return Array.from(content.children).filter(
    (child) => child instanceof HTMLElement && child !== spacer
  )
}

// Whether there is anything to scroll to in each direction — which is what
// decides the two buttons' `data-active`. `end` is measured against the
// content's own bottom rather than `scrollHeight`, because the tail spacer
// inflates `scrollHeight` on purpose and would keep the button lit forever.
export function getMessageScrollerScrollable({
  content,
  scrollEdgeThreshold,
  spacer,
  viewport
}) {
  if (!viewport || !content) return NOT_SCROLLABLE

  const contentBottom = getContentBottom({ content, spacer, viewport })

  return {
    start: viewport.scrollTop > scrollEdgeThreshold,
    end:
      contentBottom - viewport.scrollTop - viewport.clientHeight >
      scrollEdgeThreshold
  }
}

// The first anchor among rows added since the last count — what a newly
// arrived turn scrolls to.
export function getNewScrollAnchor(items, previousItemCount) {
  for (let index = previousItemCount; index < items.length; index++) {
    if (items[index]?.dataset.scrollAnchor === "true") return items[index]
  }

  return null
}

// `handledAnchors` is anything with a `has(element)` — upstream passes a
// `WeakSet` of anchors already scrolled to, so one is never handled twice.
export function getUnanchoredScrollAnchor(items, handledAnchors) {
  for (const item of items) {
    if (item.dataset.scrollAnchor === "true" && !handledAnchors.has(item)) {
      return item
    }
  }

  return null
}

// Two turns arriving in one batch cannot both be scrolled to, so the caller
// needs to know before it tries. Stops at two rather than counting them all.
export function hasMultipleNewScrollAnchors(items, previousItemCount) {
  let count = 0

  for (let index = previousItemCount; index < items.length; index++) {
    if (items[index]?.dataset.scrollAnchor !== "true") continue

    count += 1
    if (count > 1) return true
  }

  return false
}

export function getLastScrollAnchor(items) {
  for (let index = items.length - 1; index >= 0; index--) {
    if (items[index]?.dataset.scrollAnchor === "true") return items[index]
  }

  return null
}

// Rows without a `data-message-id` are skipped: the spacer is already gone, but
// a host may put its own markup in the content column and it should not count
// as a message.
export function getFirstVisibleMessageItem({ content, spacer, viewport }) {
  const viewportRect = viewport.getBoundingClientRect()

  for (const item of getMessageScrollerItems(content, spacer)) {
    if (!item.dataset.messageId) continue

    const rect = item.getBoundingClientRect()

    if (rect.bottom > viewportRect.top && rect.top < viewportRect.bottom) {
      return item
    }
  }

  return null
}

// Where the viewport has to be scrolled for `element` to sit at `align`.
// `scrollMargin` is the caller's breathing room above it; the content's own
// block padding is subtracted so the row lands where it looks right rather than
// where the box model puts it (geometry.ts:204-265).
export function getElementScrollTop({
  align,
  element,
  scrollMargin,
  spacer,
  viewport
}) {
  const elementTop = getElementTop(element, viewport)
  const elementHeight = element.getBoundingClientRect().height
  const contentPadding = getContentBlockPadding(spacer)

  if (align === "center") {
    const insetHeight = Math.max(
      0,
      viewport.clientHeight - contentPadding.start - contentPadding.end
    )

    return (
      elementTop -
      contentPadding.start -
      (insetHeight - elementHeight) / 2 -
      scrollMargin
    )
  }

  if (align === "end") {
    return (
      elementTop -
      viewport.clientHeight +
      elementHeight +
      contentPadding.end +
      scrollMargin
    )
  }

  // `nearest` is the only one that can answer "do not move".
  if (align === "nearest") {
    const elementBottom = elementTop + elementHeight
    const viewportTop = viewport.scrollTop + contentPadding.start
    const viewportBottom =
      viewport.scrollTop + viewport.clientHeight - contentPadding.end

    if (elementTop >= viewportTop && elementBottom <= viewportBottom) {
      return viewport.scrollTop
    }

    if (elementTop < viewportTop) {
      return elementTop - contentPadding.start - scrollMargin
    }

    return (
      elementBottom - viewport.clientHeight + contentPadding.end + scrollMargin
    )
  }

  return elementTop - contentPadding.start - scrollMargin
}

// In the scroll container's own coordinates, not the viewport's: the rect
// difference plus the current `scrollTop` is what makes the answer survive
// being scrolled.
export function getElementTop(element, viewport) {
  const elementRect = element.getBoundingClientRect()
  const viewportRect = viewport.getBoundingClientRect()

  return elementRect.top - viewportRect.top + viewport.scrollTop
}

export function getElementViewportTop(element, viewport) {
  return (
    element.getBoundingClientRect().top - viewport.getBoundingClientRect().top
  )
}

// How tall the spacer under the last message has to be for that message to be
// able to reach the top of the viewport. Negative means none is needed.
export function getTailSpacerHeight({ content, scrollTop, spacer, viewport }) {
  const contentBottom = getContentBottom({ content, spacer, viewport })

  return scrollTop + viewport.clientHeight - contentBottom
}

// The bottom of the real content, spacer excluded — measured from the rows
// rather than read off `scrollHeight`, which the spacer inflates. Starts at the
// padding so an empty column still answers sensibly.
export function getContentBottom({ content, spacer, viewport }) {
  const items = getMessageScrollerItems(content, spacer)
  const padding = getBlockPadding(content)
  const viewportRect = viewport.getBoundingClientRect()
  const scrollTop = viewport.scrollTop
  let contentBottom = padding.start + padding.end

  for (const item of items) {
    const rect = item.getBoundingClientRect()

    contentBottom = Math.max(
      contentBottom,
      rect.bottom - viewportRect.top + scrollTop + padding.end
    )
  }

  return contentBottom
}

export function getMaxScrollTop(viewport) {
  return Math.max(0, viewport.scrollHeight - viewport.clientHeight)
}

// `paddingBlock*` first so a vertical writing mode measures the axis that
// actually scrolls; `paddingTop`/`paddingBottom` is the fallback.
export function getBlockPadding(element) {
  const style = window.getComputedStyle(element)

  return {
    end: readCssPixel(style.paddingBlockEnd || style.paddingBottom),
    start: readCssPixel(style.paddingBlockStart || style.paddingTop)
  }
}

// Reached through the spacer rather than by taking the content element as an
// argument, because the callers that need it are holding the spacer.
export function getContentBlockPadding(spacer) {
  const content = spacer?.parentElement

  if (!content) return { end: 0, start: 0 }

  return getBlockPadding(content)
}

export function getFlexGap(element) {
  if (!element) return 0

  const style = window.getComputedStyle(element)
  const gap = style.rowGap === "normal" ? style.gap : style.rowGap

  return readCssPixel(gap)
}

// `parseFloat` on a computed length, with everything unparseable — `normal`,
// `auto`, an empty string — collapsing to 0 rather than to `NaN`, which would
// poison every sum it reaches.
function readCssPixel(value) {
  if (!value) return 0

  const number = Number.parseFloat(value)

  return Number.isFinite(number) ? number : 0
}
