# Reference sources

Copied verbatim from [`shadcn-ui/ui`](https://github.com/shadcn-ui/ui) at the
revision recorded in `REVISION`:

| Path | Upstream | Used by |
|---|---|---|
| `ui/` | `apps/v4/registry/new-york-v4/ui` | `spec/parity_spec.rb` |
| `examples/` | the theming components under `apps/v4` | `spec/components/shadcn/theming_spec.rb` |
| `themes.json` | `apps/v4/registry/themes.ts` | `rake themes:build` |

None of it is loaded at runtime. `spec/parity_spec.rb` reads `ui/` and asserts
that every Tailwind class the TSX emits also appears in the corresponding Ruby
component, which is what keeps the port honest as either side changes.
`themes.json` is the input the theme stylesheet and Ruby registry are generated
from.

To refresh:

```sh
git clone --depth 1 https://github.com/shadcn-ui/ui /tmp/shadcn-ui
cp /tmp/shadcn-ui/apps/v4/registry/new-york-v4/ui/{button,badge,…}.tsx vendor/shadcn/ui/
(cd /tmp/shadcn-ui && git rev-parse HEAD) > vendor/shadcn/REVISION

# themes.json is `apps/v4/registry/themes.ts` with the TypeScript stripped:
#   the `export const THEMES =` prefix and the `as const satisfies …` suffix.
bundle exec rake themes:build
bundle exec rspec
```

Upstream licence: MIT, see `LICENSE.md`.
