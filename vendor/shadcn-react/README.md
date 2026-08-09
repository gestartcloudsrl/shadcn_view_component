# Reference sources — `@shadcn/react`

Copied verbatim from [`shadcn-ui/ui`](https://github.com/shadcn-ui/ui) at the
revision recorded in `REVISION`, from `packages/react/src/`:

| Path | Upstream |
|---|---|
| `message-scroller/*` | `packages/react/src/message-scroller/*` |

This is the package `vendor/shadcn/ui/message-scroller.tsx` imports as
`@shadcn/react/message-scroller`. shadcn publishes it themselves — MIT, no
runtime dependencies, and its only two exports are `message-scroller` and
`questionnaire` — so unlike Radix it is *shadcn's own* behaviour rather than a
primitive they wrap.

**Why it is here at all.** The gem reimplements this in Stimulus, and a
reimplementation with nothing to check itself against is guesswork. This is the
same role `vendor/radix/` plays for the other controllers: something a person
can open when a comment claims "upstream does X".

**What was not copied:** the tests (`*.test.ts`, `*.browser.test.tsx`,
`*.perf.browser.test.tsx` — 112 KB, nearly twice the implementation) and
`PERFORMANCE.md`. Worth knowing they exist: the ratio is the clearest signal
available about how much of this component's difficulty is timing and layout
rather than logic.

`use-message-scroller-commands.ts` **is** copied although this port does not
reproduce it, so that "the imperative commands were left out" can be checked
against what was left out rather than taken on trust. See
[features/message-scroller.md](../../.claude/docs/features/message-scroller.md).

Nothing here is loaded at runtime, and — exactly as with `vendor/radix/` — **no
spec reads it**. `vendor/shadcn/` is checked by `parity_spec` on every run and
so cannot drift; this directory has no such guard and goes stale the moment
upstream ships past `REVISION`, with nothing to notice.
