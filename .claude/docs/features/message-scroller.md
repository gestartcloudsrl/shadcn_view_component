# Message scroller

**Verdict: adapted — a reimplementation of shadcn's own primitive, deliberately
narrower than it.**

**Status: complete, within the two cuts.** The five components, the controller
and the three CSS utilities ship. It opens at the live end, follows messages as
they arrive, releases when the reader scrolls up, holds the view still when
older history loads above, takes an arriving anchored turn to the top with the
previous one peeking, and lights each button from `data-scrollable`.

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
cheapest of the three slices. Ported, and worth two notes:

**The anchor has to be re-captured after scrolling, not only after a content
change.** It is "the row you are looking at", and scrolling is what changes
which row that is. Capturing on content changes alone left the restore
correcting by a delta measured from a position the reader had left — a wilder
jump than doing nothing. It is re-captured in the same frame the scroll state
commits in.

**Anchors already in the markup count as handled**, and this is the one place
server rendering forces a difference from upstream rather than a translation of
it. React mounts the component empty and fills it, so upstream's first content
change takes the `previousItemCount === 0` branch, goes to the end, and never
jumps to an anchor that was there from the start. Measured on the live demo: at
rest the tail spacer is hidden and the viewport sits at the very end.

Here the rows arrive with the document, so without seeding them the first
observer finds an unhandled anchor and takes the reader to it — a conversation
opening part-way up under a screenful of tail spacer, which upstream never
shows. `scroll_anchor` keeps its meaning for turns that *arrive*.

An earlier note in this file said the opposite: that jumping on load was
upstream's behaviour and correct. That was wrong, and wrong in the way this repo
keeps catching — asserted from the vendored source, which says what the code
does, without asking what the running component actually shows.

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

## The contract the controller and the markup have to agree on

Read from `vendor/shadcn-react/message-scroller/components.tsx` and
`use-message-scroller-controller.ts`, so the next session does not read them
again.

**`MessageScrollerProvider` renders no DOM at all** (`components.tsx:89-107`) —
it is pure context, and it is where the controller's five options live:
`autoScroll`, `defaultScrollPosition`, `scrollEdgeThreshold`,
`scrollPreviousItemPeek`, `scrollMargin`. It therefore has no counterpart here,
the same answer `useSidebar` got: the options become Stimulus values and
`data-controller` goes on the root, which is a real element.

**Attributes, all of them:**

| element | attribute | written by |
|---|---|---|
| root *and* viewport | `data-scrollable="start end"` (space-joined, removed when neither) | controller |
| root *and* viewport | `data-autoscrolling` (boolean attribute) | controller |
| item | `data-message-id`, `data-scroll-anchor="true"｜"false"` | server |
| button | `data-active="true"｜"false"` | controller |

`geometry.js` reads `data-scroll-anchor` and `data-message-id`, so those two are
the markup's side of the contract and must be rendered even before a controller
exists.

**The content column ends in a spacer** — `<div aria-hidden
data-message-scroller-spacer hidden>` (`components.tsx:301-307`), a sibling of
the items with no `data-slot`, whose height the controller sets so the last
message can reach the top of the viewport. It is the reason `getContentBottom`
exists rather than reading `scrollHeight`. The content also defaults to
`role="log"` with `aria-relevant="additions"`.

**Four modes**, held on the controller and never written to the DOM:
`following-bottom`, `free-scrolling`, `settling-jump`, `anchored-to-message`.
`reconcileFollowMode` (`:140-169`) is the only place any of them changes. Two
details in it are worth not rediscovering: arming is suppressed while
`anchored-to-message`, because the tail spacer makes a freshly anchored turn read
as "at the end" and re-arming there lets the first streamed chunk yank the reader
off the anchor; and `commitScrollState` publishes `end: false` while following,
because the raw geometry would strobe the button once per streamed chunk.

## CSS that is not Tailwind's

`scroll-fade-b`, `scrollbar-thin` and `scrollbar-gutter-stable`, on top of the
three already reproduced for `attachment`. Same caveat as those: shadcn's own
CSS, no vendored source, nothing local to diff against.

**Ported.** All three are at the end of `shadcn.css`. `scroll-fade-b` was read
rather than derived from `scroll-fade-x`, and that was the right call: it fades
one edge instead of two, so it carries a single animation rather than a pair; it
composites its mask with `mask-composite: intersect`, which the horizontal one
does not; and its timeline is `scroll(self y)` against `scroll(self inline)`.
Deriving it would have got all three wrong.

The original note, kept because the reasoning still holds:
**These blocked the markup, not the controller.** `message-scroller-viewport`
carries all three, so shipping the components without them would put three
inert classes in the bundle — which `parity_spec` cannot see, since it compares
class text and not generated CSS. `scroll-fade-b` is the vertical sibling of the
`scroll-fade-x` already in `shadcn.css` and needs its own `@property
--scroll-fade-t/b` pair and keyframes; **do not derive it from the horizontal
one**, read it from the stylesheet ui.shadcn.com serves, the way the other three
were.

## Where each claim is enforced

| Claim | Enforced by |
|---|---|
| the spacer is excluded from the rows, and the content's bottom is measured from them rather than from `scrollHeight` | `spec/system/scroll_geometry_spec.rb`, mutation-verified — dropping the exclusion fails three examples |
| `getElementTop` is in the scroller's coordinates and survives scrolling | same file, mutation-verified — dropping `+ scrollTop` fails two |
| the anchor finders, and `nearest` answering "stay where you are" | same file |
| a computed length that is `normal` reads 0 rather than `NaN` | same file |
| opening at the live end, following an arriving message, and staying put once the reader has scrolled away | `spec/system/message_scroller_spec.rb`, mutation-verified — removing the follow release fails three examples |
| each button's `data-active`, and its tab order following it | same file, and `accessibility_spec` |
| holding the reader in place through a prepend | same file, mutation-verified — **only because the example turns native scroll anchoring off first** |
| an arriving anchored turn landing at the top with the previous one peeking | same file, mutation-verified |
| a conversation whose markup already marks a turn still opening at the end | same file, against `/chat`, mutation-verified |

**The prepend example measured the browser before it measured this code.** It
passed with the entire prepend branch deleted, because Chrome anchors scroll
natively and held the position on its own. The controller exists for the engines
that do not — upstream names Safari — and its restore is deliberately written as
a correction that is a no-op where the browser got there first. The example now
sets `overflow-anchor: none` on the content, which is what asks the question
about *this* code rather than about Chrome's.

**One behaviour is deliberately unasserted.** `commitScrollState` publishes
`end: false` while following, so a streamed chunk cannot strobe the end button.
Removing that mask fails nothing: the gap it hides lasts a single frame, and an
assertion taken at a point cannot see it. Sampling across frames would be the
instrument; none exists here. Recorded rather than faked.

Everything else above is a measurement, not a guarantee: the line counts and
call sites were read from the vendored source at `vendor/shadcn-react/REVISION`,
and **no spec reads that directory** — exactly as none reads `vendor/radix/`.
