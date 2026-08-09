import { Controller } from "@hotwired/stimulus"
import {
  getContentBottom,
  getFlexGap,
  getMaxScrollTop,
  getMessageScrollerScrollable,
  getTailSpacerHeight
} from "shadcn/scroll_geometry"

// A chat log that follows its own live end, ported from
// `vendor/shadcn-react/message-scroller/` — shadcn's own primitive rather than
// a Radix one, which is why this controller has a vendored source to answer to
// at all.
//
// Two of upstream's surfaces are deliberately absent, measured and argued in
// `.claude/docs/features/message-scroller.md`: the visibility store, and
// `scrollToMessage`. Prepend anchoring is not absent so much as not here yet —
// the rows already carry `data-scroll-anchor` because `scroll_geometry.js`
// reads it, and nothing acts on it until that slice lands.

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
    scrollPreviousItemPeek: { type: Number, default: 0 }
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

    if (this.autoScrollValue && !scrollable.end) {
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

  // ---------------------------------------------------------- reacting

  handleContentChange() {
    if (this.mode === "following-bottom" && this.autoScrollValue) this.scrollToEnd()
    else this.scheduleStateCommit()
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
