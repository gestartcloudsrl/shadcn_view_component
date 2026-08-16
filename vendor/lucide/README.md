# Reference sources

The SVG files [lucide](https://lucide.dev) publishes as `lucide-static`, at the
version recorded in `REVISION`, under the ISC `LICENSE` beside them.

| Path | Upstream | Used by |
|---|---|---|
| `icons/` | `lucide-static/icons/*.svg` | `rake icons:build` |

Only the icons the ported components render are here — lucide has about 1,500,
and vendoring all of them would ship a megabyte to every host to draw twenty-one
things. What a *host* needs is its own business:
`ShadcnViewComponent::IconRegistry.load_directory` takes a directory of files
exactly like these.

None of it is loaded at runtime, and none of it ships in the gem: the gemspec
packages `{app,config,lib}`, and `rake icons:build` turns these files into
`lib/shadcn_view_component/icons.rb`, which is what `Shadcn::Icon::Component`
reads. Editing that file by hand is what the CI check catches.

They are files rather than Ruby strings because the strings went stale and one
of them was wrong: the README said eleven of what were twenty-two, and `search`
had been drawn from an older lucide, with a shorter handle than the rest of the
set.

To add one:

```sh
curl -o vendor/lucide/icons/star.svg \
  "https://unpkg.com/lucide-static@$(cat vendor/lucide/REVISION)/icons/star.svg"
bundle exec rake icons:build
```

`spec/icons_spec.rb` then requires a component to actually render it — an icon
nobody draws costs every host bytes forever.

To refresh the set, re-run that `curl` for each file in `icons/` with a new
`REVISION`, rebuild, and read the diff: a drawing that changed is a drawing
upstream redrew.
