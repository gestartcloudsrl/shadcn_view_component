// Closing a layer has two halves that used to happen in one tick, which is why
// no `data-[state=closed]:animate-out` class in this library ever played.
//
// `data-state="closed"` and everything about *interaction* — the dismiss layer,
// aria, focus, the scroll lock — has to be immediate: a layer on its way out
// must not answer Escape. Taking the element out of the DOM has to wait, or the
// exit keyframes never get a frame.
//
// `getAnimations()` rather than an `animationend` listener. The event bubbles
// from descendants, so it would need filtering by both target and name; worse,
// it never fires when no animation applies, which forces a timeout — and that
// timeout then becomes the *normal* path in a host that has not loaded this
// gem's stylesheet. An empty animation list is unambiguous and needs no
// fallback.

// The animations worth holding a teardown for: the ones already under way that
// are also going to end.
//
// `playState === "running"` on its own is not that: an
// `animation-iteration-count: infinite` animation reports `"running"` and has
// no end to reach. Caller classes concatenate onto a component's own, so a host
// utility carrying one — `animate-pulse` among them — can land on closing
// content through supported API, and waiting on its `finished` leaves the layer
// in the document, painted and `pointer-events: none`, after everything that
// closes it has already run. Measured before this filter existed: an Escaped
// dialog still in the document five seconds later, `hidden` never set. An
// animation that never ends is not the exit either way, so nothing is lost by
// leaving it out. A timeout was the alternative: an arbitrary constant, and the
// layer would still be stuck for its length.
//
// `endTime` rather than `iterations` because it is the one number that answers
// "will this ever end" whatever put the animation there. Measured in headless
// Chrome: `Infinity` for both spellings — CSS `infinite` and
// `element.animate(…, { iterations: Infinity })` — and not a number at all for
// an animation on a `scroll()` timeline, which has no end on a clock either.
// `Number.isFinite` rejects all three.
const willEnd = (animation) =>
  animation.playState === "running" &&
  Number.isFinite(animation.effect?.getComputedTiming()?.endTime)

// Holds teardowns that are waiting on an element's exit animation, one per
// element.
export class ExitQueue {
  constructor() {
    this.pending = new Map()
    this.generation = 0
    this.onBeforeCache = null
  }

  // Runs `teardown` once the animations already running on `element` have
  // finished — or immediately and synchronously when there are none. That last
  // part is the point: a host that never loaded this stylesheet, a host that
  // overrode the classes away, and a host whose only animation here is an
  // endless one all keep exactly today's behaviour.
  //
  // A second call for an element already waiting is ignored, so a `turbo:morph`
  // re-render in the middle of an exit cannot queue the same teardown twice.
  defer(element, teardown) {
    if (this.pending.has(element)) return

    const running = element.getAnimations().filter(willEnd)

    if (!running.length) {
      teardown()
      return
    }

    // Marks the element as exiting for the length of the animation only — it
    // is never rendered markup. Read by `[data-slot][data-exiting]` in
    // shadcn.css, which stops most exiting elements intercepting clicks, as
    // Radix does; that rule, not this marker, is what carries the accordion's
    // exception.
    element.dataset.exiting = ""

    // `data-exiting` and `inert` are not two spellings of one thing: the
    // marker above is a CSS hook, deliberately excluded for the accordion so
    // its collapsing panel keeps taking clicks; `inert` takes the element out
    // of the tab order and the accessibility tree, with no such exception —
    // `hidden` used to do both, in the same tick, before it started waiting
    // on this queue.
    element.inert = true

    // Tags this call's continuation with the generation it belongs to. Without
    // it, cancel() followed by a fresh defer() in the same tick — reopen then
    // close again before the first exit's promise has settled — would let the
    // first continuation flush the second exit's teardown as soon as it drains,
    // dismounting a layer whose new animation has barely started.
    const generation = ++this.generation
    this.pending.set(element, { teardown, generation })
    this.watchTurbo()

    // Reopening mid-exit cancels the animation, which rejects `finished`. Either
    // way the waiting is over; whether the teardown still applies is decided by
    // whoever calls `cancel`.
    Promise.all(running.map((a) => a.finished))
      .catch(() => {})
      .then(() => {
        if (this.pending.get(element)?.generation === generation) this.flush(element)
      })
  }

  // Runs a pending teardown now. Called when the animation ends, and directly
  // from `disconnect()`, where waiting is not an option: Turbo may be detaching
  // the element, and a continuation would then be operating on a subtree that
  // has left the document.
  flush(element) {
    const entry = this.pending.get(element)
    if (!entry) return

    this.pending.delete(element)
    delete element.dataset.exiting
    element.inert = false
    this.unwatchTurbo()
    entry.teardown()
  }

  // Drops a pending teardown without running it — the element is opening again,
  // so there is nothing left to take out of the DOM.
  cancel(element) {
    if (!this.pending.delete(element)) return

    delete element.dataset.exiting
    element.inert = false
    this.unwatchTurbo()
  }

  has(element) {
    return this.pending.has(element)
  }

  flushAll() {
    for (const element of [ ...this.pending.keys() ]) this.flush(element)
  }

  // A pending teardown must never survive into a Turbo snapshot. `cacheSnapshot()`
  // clones whatever is in the document while handling `turbo:before-cache` — well
  // inside an exit animation's duration — so without this a layer closed by the
  // same pointerdown that starts a Drive navigation gets cached mid-exit: wrapper,
  // placeholder and `data-exiting` all cloned in. A later restore built from that
  // clone would then nest a second wrapper the next time the layer opens, and the
  // surviving `data-exiting` would leave it unclickable.
  //
  // One listener per queue, added only while something is pending and removed
  // as soon as nothing is, rather than one at module load: most pages never
  // have an exit in flight when they navigate away.
  watchTurbo() {
    if (this.onBeforeCache) return

    this.onBeforeCache = () => this.flushAll()
    document.addEventListener("turbo:before-cache", this.onBeforeCache)
  }

  unwatchTurbo() {
    if (this.pending.size || !this.onBeforeCache) return

    document.removeEventListener("turbo:before-cache", this.onBeforeCache)
    this.onBeforeCache = null
  }
}
