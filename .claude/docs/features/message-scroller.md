# Message scroller

**Verdict: adapted — a reimplementation of shadcn's own primitive, deliberately
narrower than it.**

**Status: geometry ported, nothing else.** `app/javascript/shadcn/scroll_geometry.js`
is the first slice — 17 pure functions, no controller yet. The rest of this file
records the measurements and the two cuts agreed before any code was written.

**Upstream:** `vendor/shadcn/ui/message-scroller.tsx` is a thin wrapper — six
parts, all delegating — over `@shadcn/react/message-scroller`, which shadcn
publishes themselves: MIT, no runtime dependencies, two exports in the whole
package. Vendored at [`vendor/shadcn-react/`](../../../vendor/shadcn-react/README.md)
so the port has something to be answerable to, the role `vendor/radix/` plays
for the other controllers.

---

## What it is, measured

| file | lines |
|---|---|
| `use-message-scroller-controller.ts` | 758 |
| `components.tsx` | 429 |
| `geometry.ts` | 387 |
| `use-message-scroller-commands.ts` | 326 |
| `types.ts` | 239 (types only) |
| `use-message-scroller-refs.ts` | 172 |
| `stores.ts` | 97 |
| `index.ts` | 31 |

**2,439 lines.** The tests upstream ships and this repo did not vendor come to
112 KB — close to twice the implementation — and include a browser performance
suite and a `PERFORMANCE.md`. That ratio is the clearest available statement of
where this component's difficulty lives: timing and layout, not logic.

For scale: `select_controller.js` is 315 lines, and every shared module in this
gem together — popper, floating, animation, dismiss, focus, typeahead, theme —
is 1,072.

## The two cuts, and what they are actually worth

Agreed before implementation, on the measurements below rather than on
impressions.

### Cut: the visibility surface

`useMessageScrollerVisibility` reports which messages are on screen and which
anchored turn is "current". It has no Stimulus equivalent — it is an API for the
host application to drive its own UI with, and designing that surface is a
decision rather than a translation.

Cheap to remove, and cleanly: `scheduleVisibilitySync` returns on its first line
unless something has subscribed (`visibilityStore.hasListeners()`), and it feeds
`visibilityStore` and nothing else. The `IntersectionObserver` exists only to
maintain the id set it reads, so it goes too.

**Worth ~161 lines**: `getMessageScrollerVisibilityState` (71, the largest
function in `geometry.ts`), plus roughly 90 of controller plumbing — the sync
callback, the observer, the refs and the store.

### Cut: scroll-to-message

`scrollToMessage` and its pending-flush queue. A host that wants to jump to a
message can hold the element and scroll it itself; reproducing the queue means
inventing the API for it as well.

**Worth 72 lines**, both in `use-message-scroller-commands.ts`.

### What was *not* cut, against an earlier claim that it could be

An estimate made before reading the call graph said the whole 326-line commands
file could go, along with `getElementScrollTop` (63), `getTailSpacerHeight` (16)
and `getMaxScrollTop` (4) in geometry. Measured, that is wrong:

- `scrollToElement` — 61 lines, called six times by the controller and required
  by the anchoring behaviour — uses `getElementScrollTop`, `getTailSpacerHeight`
  and `getElementViewportTop`.
- `scrollToEnd` — what the end button calls — uses `getMaxScrollTop`.

So `geometry.ts` reduces 387 → ~316, not to ~210, and the commands file 326 →
~254, not to nothing.

### Kept deliberately: prepend anchoring

`capturePrependAnchor` / `restorePrependedAnchor`, and the four anchor-finding
functions in geometry (~60 lines). Keeping the viewport steady when older
messages load above is the behaviour a chat log is judged on, and it is the
cheapest of the three slices.

## Estimate

**850–1,000 lines of Stimulus**, against 2,439 of TypeScript. Most of the
difference is not cuts: `stores.ts` and most of `use-message-scroller-refs.ts`
are `useSyncExternalStore` plumbing that exists because React needs a bridge to
external state, and in Stimulus the DOM is already that store.

`geometry.ts` was the piece done first — pure functions over
`getBoundingClientRect`, `scrollTop` and two `data-` attributes, no React at
all, so it transcribed nearly line for line.

**Correcting the plan on one point:** that slice was described as
unit-testable without a browser. It is not, because this gem has no npm and
nothing runs its JavaScript outside Chrome. `spec/system/scroll_geometry_spec.rb`
builds a synthetic scroller, imports the module through the importmap and calls
the functions directly — unit tests in everything but the runner. Real layout
turns out to be the better instrument anyway: every one of these functions
exists because `scrollHeight`, `getBoundingClientRect` and computed padding
disagree in ways only a browser produces, and a stubbed rect would assert the
stub.

## CSS that is not Tailwind's

`scroll-fade-b`, `scrollbar-thin` and `scrollbar-gutter-stable`, on top of the
three already reproduced for `attachment`. Same caveat as those: shadcn's own
CSS, no vendored source, nothing local to diff against.

## Where each claim is enforced

| Claim | Enforced by |
|---|---|
| the spacer is excluded from the rows, and the content's bottom is measured from them rather than from `scrollHeight` | `spec/system/scroll_geometry_spec.rb`, mutation-verified — dropping the exclusion fails three examples |
| `getElementTop` is in the scroller's coordinates and survives scrolling | same file, mutation-verified — dropping `+ scrollTop` fails two |
| the anchor finders, and `nearest` answering "stay where you are" | same file |
| a computed length that is `normal` reads 0 rather than `NaN` | same file |

Everything else above is a measurement, not a guarantee: the line counts and
call sites were read from the vendored source at `vendor/shadcn-react/REVISION`,
and **no spec reads that directory** — exactly as none reads `vendor/radix/`.
