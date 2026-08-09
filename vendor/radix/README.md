# Reference sources

Copied verbatim from [`radix-ui/primitives`](https://github.com/radix-ui/primitives)
at the revision recorded in `REVISION`:

| Path | Upstream |
|---|---|
| `ui/hover-card.tsx` | `packages/react/hover-card/src/hover-card.tsx` |
| `ui/menu.tsx` | `packages/react/menu/src/menu.tsx` |
| `ui/scroll-area.tsx` | `packages/react/scroll-area/src/scroll-area.tsx` |
| `ui/navigation-menu.tsx` | `packages/react/navigation-menu/src/navigation-menu.tsx` |
| `ui/roving-focus-group.tsx` | `packages/react/roving-focus/src/roving-focus-group.tsx` |
| `ui/select.tsx` | `packages/react/select/src/select.tsx` |

None of it is loaded at runtime, and unlike `vendor/shadcn/`, **no spec reads
it**. `vendor/shadcn/` is checked by `parity_spec` on every run, so it cannot
drift from what the Ruby components claim to match; this directory has no
such guard. It exists to be read by a person checking a specific claim about
Radix's behaviour — the `loop` default a roving-focus comment cites, say —
against the actual source, not to be trusted as a standing, policed
reference. It can go stale the moment Radix ships past `REVISION` and nothing
here will notice.

It is also intentionally partial: three files, not the primitives package.
A claim about behaviour these files don't implement — Popper's repositioning
during an exit animation, for instance — is still not checkable from this
directory, and comments should keep hedging those rather than treat
"Radix is vendored now" as blanket license to drop hedging everywhere.

To refresh:

```sh
git clone --depth 1 https://github.com/radix-ui/primitives /tmp/radix-primitives
cp /tmp/radix-primitives/packages/react/menu/src/menu.tsx vendor/radix/ui/
cp /tmp/radix-primitives/packages/react/roving-focus/src/roving-focus-group.tsx vendor/radix/ui/
cp /tmp/radix-primitives/packages/react/select/src/select.tsx vendor/radix/ui/
(cd /tmp/radix-primitives && git rev-parse HEAD) > vendor/radix/REVISION
```

Upstream licence: MIT, see `LICENSE`.
