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
  // part is the point: a host that never loaded this stylesheet, or a host that
  // overrode the classes away, keeps exactly today's behaviour.
  //
  // A second call for an element already waiting is ignored, so a `turbo:morph`
  // re-render in the middle of an exit cannot queue the same teardown twice.
  defer(element, teardown) {
    if (this.pending.has(element)) return

    const running = element.getAnimations().filter((a) => a.playState === "running")

    if (!running.length) {
      teardown()
      return
    }

    // Read by `[data-slot][data-exiting]`, which stops the element intercepting
    // clicks while it fades. Radix does the same; without it a dialog overlay
    // swallows clicks for the 200ms it takes to disappear. The attribute exists
    // only for the length of the animation — it is never rendered markup.
    element.dataset.exiting = ""

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
    this.unwatchTurbo()
    entry.teardown()
  }

  // Drops a pending teardown without running it — the element is opening again,
  // so there is nothing left to take out of the DOM.
  cancel(element) {
    if (!this.pending.delete(element)) return

    delete element.dataset.exiting
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
