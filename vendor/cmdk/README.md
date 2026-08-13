# cmdk

The command palette `command.tsx` wraps. Vendored for the same reason
`vendor/radix/` is: the behaviour is reimplemented in Stimulus here, and a
reimplementation with nothing to check itself against is guesswork.

| | |
|---|---|
| `index.tsx` | the component — filtering, grouping, the keyboard, and the `cmdk-*` attributes shadcn's classes select |
| `command-score.ts` | the fuzzy scorer, which is what makes a palette feel like one: `app/javascript/shadcn/command_score.js` is a port of this file |

**Nothing here is read by any spec.** It can go stale the moment upstream ships
past the commit in `REVISION`, exactly like `vendor/radix/`. It is a citation
source, not a fixture — see
[decisions/03-testing.md](../../.claude/docs/decisions/03-testing.md#what-the-vendored-references-are-worth).

MIT, and the licence is beside it.

## Refreshing

```sh
curl -sL https://raw.githubusercontent.com/pacocoursey/cmdk/main/cmdk/src/index.tsx -o vendor/cmdk/index.tsx
curl -sL https://raw.githubusercontent.com/pacocoursey/cmdk/main/cmdk/src/command-score.ts -o vendor/cmdk/command-score.ts
```

Then update `REVISION` with the commit those files were taken from.
