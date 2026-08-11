# Reference source

`style.css`, copied verbatim from [`emilkowalski/vaul`](https://github.com/emilkowalski/vaul)
(`src/style.css`) at the revision in `REVISION`.

It is here because it is the one piece of the Drawer that `vendor/shadcn/`
cannot show. shadcn's `drawer.tsx` renders no entrance animation and no
`touch-action` of its own: both live in this file, which vaul's own package
ships and which the component does not work without. `touch-action: none` in
particular is load-bearing rather than decorative — without it the browser
claims the vertical gesture and the drag never starts.

Like `vendor/radix/`, **no spec reads this** and nothing here notices when vaul
ships past `REVISION`. Unlike `vendor/shadcn/`, it is not policed by
`parity_spec`, which compares Tailwind class *text* and cannot see a rule in a
stylesheet at all.

What was reproduced in `app/assets/stylesheets/shadcn.css` is the part this port
uses: `touch-action`, the transition, and the eight slide keyframes with the
`[data-vaul-snap-points='false']` rules that select them. The snap-point,
nested-drawer and `[data-vaul-handle]` rules were not — this port ships none of
those three features, and a rule whose selector can never match is a rule that
looks like support for something that is not there.

To refresh:

```sh
git clone --depth 1 https://github.com/emilkowalski/vaul /tmp/vaul
cp /tmp/vaul/src/style.css vendor/vaul/
(cd /tmp/vaul && git rev-parse HEAD) > vendor/vaul/REVISION
```

Upstream licence: MIT, see `LICENSE`.
