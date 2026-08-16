# The icons come from files, not from a hash

*Design, 16 August 2026. Written before the branch; what came out of it is in
the README's icon section and in
[decisions/01-architecture.md](../decisions/01-architecture.md).*

## What is wrong today

`Icon::Component::PATHS` is 22 lucide drawings typed into Ruby as
`%(<path d="…"/>)` strings. Three things follow from that, and all three have
already happened:

1. **The count in prose goes stale and nothing notices.** The README and two
   comments in `app/components/shadcn/icon.rb` say *eleven*. There are 22. The
   set grew one component at a time and the sentence did not.
2. **A drawing gets retyped and comes out wrong.** The dummy's own icon
   initializer says so in its comment: *"Drawings copied from
   `lucide-static@1.31.0` rather than retyped — one of them was wrong when it
   was."*
3. **A host adding a twelfth icon has to paste path data.** The dummy — which
   is a host, and the only one this repo can see — needed five more for the
   command palette and pasted five multi-line Ruby strings.

## What was rejected, and why

**`inline_svg`.** It resolves files through the *host's* asset pipeline, and
this engine already admits it cannot see one — `next unless
app.config.respond_to?(:assets)`. These icons are not the host's decoration;
they are inside the gem's own markup, in 54 files. A precompile that misses
them takes the close button off every Dialog in production while development
looks fine. It would also be I/O per render where there is a frozen hash today,
a fifth runtime dependency bought for a file layout, and it would inline
lucide's own `<svg>` element — whose attributes this component owns 1:1.

**Reading the directory at boot** puts I/O in the startup of an application
that is not ours. **Reading each file lazily** is `inline_svg` without the
pipeline and is a real option, but it leaves the drawings out of every diff.

## The design

**Source.** `vendor/lucide/` — the SVG files as `lucide-static` publishes them,
pinned in `vendor/lucide/REVISION`, with its ISC `LICENSE`. Only the icons the
gem's own components render; vendoring all ~1,500 would ship a megabyte to
every host to draw twenty-two things.

**Generator.** `rake icons:build` reads them, takes the children of the `<svg>`
element, and writes `lib/shadcn_view_component/icons.rb` — one frozen hash with
the banner the theme registry already carries. CI regenerates and fails on a
diff, the line that exists for themes.

**Runtime.** `Icon::Component` reads that hash. No boot I/O, no file read per
render, no dependency, nothing that touches the host's pipeline. What ships is
what shipped before; only the *source* moved.

**The host's half.** `IconRegistry.load_directory(path)` — the same extractor,
at runtime, opt-in and paid for by whoever calls it. A host drops SVGs in a
directory and points at it. The dummy's five pasted drawings become five files
and one line, which is the system's first user proving it.

**The invariant that replaces the count.** A spec that reads every literal
icon name out of the component sources and fails if one is not bundled — and
the other way, if something bundled is drawn nowhere. Its blind spot, named
rather than papered over: a name computed at runtime cannot be seen, and the
previews may legitimately ask for icons the gem does not bundle, which is what
the dummy registers.

## Deliberately not in this design

- **`aria-hidden` on decorative icons.** True of all 54 call sites and a
  separate decision; folding it in would hide an accessibility change inside a
  refactor.
- **Bundling more of lucide, or a second icon set.** Nothing asks for either
  yet. `load_directory` is the seam where both would go.
