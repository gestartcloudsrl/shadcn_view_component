import { Controller } from "@hotwired/stimulus"
import {
  getElementScrollTop,
  getElementViewportTop,
  getFirstVisibleMessageItem,
  getFlexGap,
  getMaxScrollTop,
  getMessageScrollerItems,
  getMessageScrollerScrollable,
  getNewScrollAnchor,
  getTailSpacerHeight,
  getUnanchoredScrollAnchor,
  hasMultipleNewScrollAnchors
} from "shadcn/scroll_geometry"

// A chat log that follows its own live end, ported from
// `vendor/shadcn-react/message-scroller/` — shadcn's own primitive rather than
// a Radix one, which is why this controller has a vendored source to answer to
// at all.
//
// Two of upstream's surfaces are deliberately absent, measured and argued in
// `.claude/docs/features/message-scroller.md`: the visibility store, and
// `scrollToMessage`.

// Upstream's `AUTOSCROLLING_CLEAR_DELAY` (types.ts:22): how long
// `data-autoscrolling` outlives a programmatic smooth scroll.
const AUTOSCROLLING_CLEAR_DELAY = 180
// Upstream's `SCROLL_POSITION_EPSILON` (types.ts:18). Sub-pixel scroll
// positions are normal, so "the same place" needs a tolerance.
const EPSILON = 0.5

export default class extends Controller {
  static targets = [ "viewport", "content", "spacer", "button" ]
  static values = {
    autoScroll: { type: Boolean, default: false },
    defaultScrollPosition: { type: String, default: "end" },
    // The distance from an edge that still counts as being at it. Upstream
    // leaves this undefined and falls back inside the primitive; the fallback
    // is here instead, which is the only place it can be in a Stimulus value.
    scrollEdgeThreshold: { type: Number, default: 8 },
    scrollMargin: { type: Number, default: 0 },
    // How much of the previous turn stays visible above an anchored one, so it
    // reads as a continuation rather than as the top of the world.
    scrollPreviousItemPeek: { type: Number, default: 64 },
    // Upstream hangs this off the *viewport* (components.tsx:131). Here every
    // option is a value on the root, because the element that would have
    // carried them — the Provider — renders no DOM at all.
    preserveScrollOnPrepend: { type: Boolean, default: true }
  }

  connect() {
    if (!this.hasViewportTarget || !this.hasContentTarget) return

    // `following-bottom` or `free-scrolling`. Upstream carries two more —
    // `settling-jump` and `anchored-to-message` — which only the anchoring
    // slice can enter.
    this.mode = this.autoScrollValue ? "following-bottom" : "free-scrolling"
    this.autoscrolling = false
    this.lastScrollTop = 0
    this.spacerHeight = 0
    this.frame = null
    this.autoscrollingTimer = null

    // What a content change is measured against. `handledAnchors` is a WeakSet
    // so an anchor removed from the DOM stops being remembered along with it.
    const items = this.items()

    this.itemCount = items.length
    this.firstItem = items[0] ?? null
    this.prependAnchor = null

    // Anchors already in the markup count as handled, and this is the one place
    // server rendering forces a difference from upstream rather than a
    // translation of it. React mounts this component empty and fills it, so its
    // first content change takes the `previousItemCount === 0` branch, goes to
    // the end, and never jumps to an anchor that was there from the start.
    // Measured on the live demo: at rest the tail spacer is hidden and the
    // viewport sits at the very end, anchored last turn or not.
    //
    // Here the rows arrive with the document. Without this the first observer
    // finds an unhandled anchor and takes the reader to it, so a conversation
    // opens part-way up with a screenful of tail spacer below — which upstream
    // never shows. `scroll_anchor` keeps its meaning for turns that *arrive*.
    this.handledAnchors = new WeakSet()
    for (const item of items) {
      if (item.dataset.scrollAnchor === "true") this.handledAnchors.add(item)
    }

    this.onScroll = () => this.scheduleStateCommit()
    this.viewportTarget.addEventListener("scroll", this.onScroll, { passive: true })

    // Content changing is a *DOM* event here, exactly as it is upstream: the
    // React version does not learn about new messages from re-rendering, it
    // observes them (components.tsx). So the mechanism transfers unchanged —
    // rows arriving, and rows growing as they stream.
    this.mutations = new MutationObserver(() => this.handleContentChange())
    this.mutations.observe(this.contentTarget, { childList: true, subtree: true, characterData: true })

    this.resizes = new ResizeObserver(() => this.handleResize())
    this.resizes.observe(this.contentTarget)
    this.resizes.observe(this.viewportTarget)

    this.applyDefaultScrollPosition()
    this.commitScrollState()
    this.capturePrependAnchor()
  }

  disconnect() {
    this.viewportTarget?.removeEventListener("scroll", this.onScroll)
    this.mutations?.disconnect()
    this.resizes?.disconnect()
    if (this.frame) cancelAnimationFrame(this.frame)
    if (this.autoscrollingTimer) clearTimeout(this.autoscrollingTimer)
  }

  // What the two buttons call. Which end is its own `data-direction`, so one
  // action serves both.
  jump(event) {
    const button = event.currentTarget

    if (button.dataset.direction === "start") this.scrollToStart({ behavior: "smooth" })
    else this.scrollToEnd({ behavior: "smooth" })
  }

  // ---------------------------------------------------------------- state

  // `data-scrollable` and `data-autoscrolling` go on the root *and* the
  // viewport, as upstream writes them (:107-131) — the viewport needs the
  // second for `data-autoscrolling:scrollbar-none`, and the root carries both
  // so a host can style from either.
  writeStateAttributes(state) {
    const scrollable = [ state.start && "start", state.end && "end" ].filter(Boolean).join(" ")

    for (const element of [ this.element, this.viewportTarget ]) {
      if (scrollable) element.setAttribute("data-scrollable", scrollable)
      else element.removeAttribute("data-scrollable")

      element.toggleAttribute("data-autoscrolling", this.autoscrolling)
    }

    if (this.hasButtonTarget) {
      for (const button of this.buttonTargets) {
        const active = button.dataset.direction === "start" ? state.start : state.end

        button.dataset.active = String(active)
        // In step with `data-active`, never behind it: the button is invisible
        // and `pointer-events-none` while inactive, so a tab stop there is one
        // a pointer does not have.
        if (active) button.removeAttribute("tabindex")
        else button.setAttribute("tabindex", "-1")
      }
    }
  }

  // The one place `mode` changes. Content growing past the live edge also reads
  // as "not at the end", so following must only be released by the reader
  // actually scrolling *up* — which is the only thing that lowers `scrollTop`.
  reconcileFollowMode(scrollable) {
    const scrollTop = this.viewportTarget.scrollTop
    const scrolledUp = scrollTop < this.lastScrollTop - EPSILON

    this.lastScrollTop = scrollTop

    // Arming is suppressed while anchored or settling, and that is the subtle
    // half. A freshly anchored turn sits above a tail spacer, which makes it
    // read as "at the end" — re-arming there would let the first streamed chunk
    // pull the reader off the row they were just taken to.
    if (
      this.autoScrollValue &&
      !scrollable.end &&
      this.mode !== "settling-jump" &&
      this.mode !== "anchored-to-message"
    ) {
      this.mode = "following-bottom"
    } else if (this.mode === "following-bottom" && scrollable.end && scrolledUp && !this.autoscrolling) {
      this.mode = "free-scrolling"
    }
  }

  commitScrollState() {
    const state = this.scrollable()

    this.reconcileFollowMode(state)

    // While following, the scroller is already closing whatever gap a streamed
    // chunk just opened, so publishing that gap would strobe the end button
    // once per chunk. Reconcile runs on the raw geometry first, so a commit
    // that *releases* following still publishes the gap it released over.
    this.writeStateAttributes(
      this.mode === "following-bottom" ? { ...state, end: false } : state
    )
  }

  scheduleStateCommit() {
    if (this.frame !== null) return

    this.frame = requestAnimationFrame(() => {
      this.frame = null
      this.commitScrollState()
      // Re-captured after every settled scroll, not only after a content
      // change: the anchor is "the row you are looking at", and scrolling is
      // what changes which row that is. Leaving it behind makes the next
      // prepend correct by a delta measured from somewhere you have left —
      // which is a wilder jump than doing nothing at all.
      this.capturePrependAnchor()
    })
  }

  scrollable() {
    return getMessageScrollerScrollable({
      content: this.contentTarget,
      scrollEdgeThreshold: this.scrollEdgeThresholdValue,
      spacer: this.spacer,
      viewport: this.viewportTarget
    })
  }

  // --------------------------------------------------------------- moving

  // Set while a programmatic scroll is in flight and cleared on a timer, not on
  // an event: `scrollend` is not everywhere yet, and the flag's job is to stop
  // the animation's own scroll events from releasing follow mode.
  setAutoScrolling(autoscrolling) {
    if (this.autoscrollingTimer) {
      clearTimeout(this.autoscrollingTimer)
      this.autoscrollingTimer = null
    }

    if (this.autoscrolling !== autoscrolling) {
      this.autoscrolling = autoscrolling
      this.commitScrollState()
    }

    if (!autoscrolling) return

    this.autoscrollingTimer = setTimeout(() => {
      this.autoscrollingTimer = null
      this.autoscrolling = false
      this.commitScrollState()
    }, AUTOSCROLLING_CLEAR_DELAY)
  }

  scrollToPosition(scrollTop, { behavior = "auto", autoscrolling = false } = {}) {
    const next = Math.max(0, scrollTop)

    // Already there: assign rather than animate, or a smooth scroll to where we
    // stand never fires and the commit never comes.
    if (Math.abs(this.viewportTarget.scrollTop - next) <= EPSILON) {
      this.viewportTarget.scrollTop = next
      this.commitScrollState()
      return
    }

    if (autoscrolling) this.setAutoScrolling(true)

    this.viewportTarget.scrollTo({ top: next, behavior })
    this.scheduleStateCommit()
  }

  scrollToStart({ behavior = "auto" } = {}) {
    this.setTailSpacerHeight(0)
    this.mode = "free-scrolling"
    this.scrollToPosition(0, { behavior })
  }

  scrollToEnd({ behavior = "auto" } = {}) {
    this.setTailSpacerHeight(0)
    this.mode = this.autoScrollValue ? "following-bottom" : "free-scrolling"
    this.scrollToPosition(getMaxScrollTop(this.viewportTarget), { autoscrolling: true, behavior })
  }

  // The spacer under the last row, sized so that row can reach the *top* of the
  // viewport instead of stopping at the bottom. The negative margin cancels the
  // content column's own gap, which would otherwise be counted twice — once as
  // the gap above the spacer and once as the height asked for here.
  setTailSpacerHeight(height) {
    if (!this.hasSpacerTarget) return

    const next = Math.max(0, Math.ceil(height))
    if (this.spacerHeight === next) return

    this.spacerHeight = next
    this.spacerTarget.hidden = next === 0
    this.spacerTarget.style.height = `${next}px`
    this.spacerTarget.style.marginTop = next > 0 ? `${-getFlexGap(this.contentTarget)}px` : ""
  }

  // Take a row to the top of the viewport, sizing the tail spacer so it can
  // actually get there — without it, the last messages stop at the bottom.
  // `keepPreviousPeek` leaves the previous turn showing above, which is what
  // makes an arriving turn read as a continuation.
  scrollToElement(element, { align = "start", behavior = "auto", keepPreviousPeek = false } = {}) {
    if (!this.contentTarget.contains(element)) return false

    const scrollMargin = keepPreviousPeek
      ? this.scrollMarginValue + this.scrollPreviousItemPeekValue
      : this.scrollMarginValue

    const scrollTop = getElementScrollTop({
      align, element, scrollMargin, spacer: this.spacer, viewport: this.viewportTarget
    })

    this.setTailSpacerHeight(this.tailSpacerFor(scrollTop))

    // Seed the prepend anchor with the jump target, so a prepend landing before
    // this scroll settles still preserves the row we were taken to.
    this.prependAnchor = {
      element,
      viewportTop: getElementViewportTop(element, this.viewportTarget)
    }

    this.mode = keepPreviousPeek ? "anchored-to-message" : "settling-jump"
    this.scrollToPosition(scrollTop, { behavior })

    return true
  }

  // ------------------------------------------------------------- prepend

  // The first visible row and where it sits *relative to the viewport*. That
  // frame of reference is the whole trick: it is what survives rows being
  // inserted above it.
  capturePrependAnchor() {
    const anchor = getFirstVisibleMessageItem({
      content: this.contentTarget,
      spacer: this.spacer,
      viewport: this.viewportTarget
    })

    this.prependAnchor = anchor
      ? { element: anchor, viewportTop: getElementViewportTop(anchor, this.viewportTarget) }
      : null
  }

  // Correct the scroll by however far the remembered row moved. Where the
  // browser's own scroll anchoring already handled the prepend the delta is
  // zero and this does nothing — which is why it corrects a measurement rather
  // than checking a capability flag, since engines misreport those.
  restorePrependedAnchor() {
    const anchor = this.prependAnchor

    if (!anchor || !anchor.element.isConnected) return false

    const delta = getElementViewportTop(anchor.element, this.viewportTarget) - anchor.viewportTop

    if (Math.abs(delta) <= EPSILON) return false

    this.viewportTarget.scrollTop += delta
    anchor.viewportTop = getElementViewportTop(anchor.element, this.viewportTarget)
    this.scheduleStateCommit()

    return true
  }

  // ---------------------------------------------------------- reacting

  // Branch order is load-bearing, and it is upstream's (:393-481): a prepend is
  // not an append, and an arriving turn is not a row that merely grew.
  handleContentChange() {
    const items = this.items()
    const previousCount = this.itemCount
    const previousFirst = this.firstItem

    this.itemCount = items.length
    this.firstItem = items[0] ?? null

    this.reconcileScrollPosition(items, previousCount, previousFirst)
    this.capturePrependAnchor()
  }

  reconcileScrollPosition(items, previousCount, previousFirst) {
    if (previousCount === 0) {
      if (items.length > 0 && this.autoScrollValue) return this.scrollToEnd()

      return this.scheduleStateCommit()
    }

    // Rows arrived *above* the ones already there, which is what loading older
    // history looks like. Hold the view still rather than treating them as new.
    const previousFirstIndex = previousFirst ? items.indexOf(previousFirst) : -1

    if (this.preserveScrollOnPrependValue && previousFirstIndex > 0) {
      return this.restorePrependedAnchor()
    }

    if (items.length > previousCount) {
      const anchor = getNewScrollAnchor(items, previousCount)

      if (anchor) {
        // A batch of several anchored turns landing at once should keep
        // following the end rather than yank back to anchor the first of them.
        if (
          this.autoScrollValue &&
          this.mode === "following-bottom" &&
          hasMultipleNewScrollAnchors(items, previousCount)
        ) {
          return this.scrollToEnd()
        }

        this.scrollToElement(anchor, { keepPreviousPeek: true })
        this.handledAnchors.add(anchor)
        return true
      }
    }

    // Same rows, but one of them just became an anchor — a turn marked after it
    // was already on the page.
    if (items.length === previousCount) {
      const anchor = getUnanchoredScrollAnchor(items, this.handledAnchors)

      if (anchor) {
        this.scrollToElement(anchor, { keepPreviousPeek: true })
        this.handledAnchors.add(anchor)
        return true
      }
    }

    if (this.mode === "following-bottom" && this.autoScrollValue) return this.scrollToEnd()

    return this.scheduleStateCommit()
  }

  items() {
    return getMessageScrollerItems(this.contentTarget, this.spacer)
  }

  // A resize is not a content change: rows growing as they stream arrive here
  // rather than through the mutation observer, and the answer is the same one.
  handleResize() {
    this.handleContentChange()
  }

  applyDefaultScrollPosition() {
    if (this.defaultScrollPositionValue === "start") {
      this.scrollToPosition(0)
      return
    }

    this.scrollToPosition(getMaxScrollTop(this.viewportTarget))
  }

  // `hasSpacerTarget` guards every caller, so this can hand back null and let
  // the geometry treat the column as spacer-less.
  get spacer() {
    return this.hasSpacerTarget ? this.spacerTarget : null
  }

  // Kept because `getContentBottom` and `getTailSpacerHeight` are what the
  // anchoring slice will size the spacer from, and importing them here is what
  // will make that a change to one method rather than to the import list.
  contentBottom() {
    return getContentBottom({
      content: this.contentTarget,
      spacer: this.spacer,
      viewport: this.viewportTarget
    })
  }

  tailSpacerFor(scrollTop) {
    return getTailSpacerHeight({
      content: this.contentTarget,
      scrollTop,
      spacer: this.spacer,
      viewport: this.viewportTarget
    })
  }
}
