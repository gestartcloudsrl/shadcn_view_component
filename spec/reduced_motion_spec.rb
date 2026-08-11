# frozen_string_literal: true

require "spec_helper"

# Guards the reduced-motion override in the *compiled* Tailwind bundle, not the
# CSS source. `exit_animation_spec.rb` runs under `--force-prefers-reduced-motion`,
# but its own `force_animations` helper immediately overrides the duration by
# setting it inline on the element, so the animation can be observed for the
# rest of that file's assertions — so it cannot see whether the shipped CSS
# collapses duration under reduced motion at all. This spec reads the build
# output directly instead.
#
# `animate-accordion-down`/`animate-accordion-up` are both `@utility` names in
# shadcn.css *and* `--animate-*` theme keys (the keys have to exist — see the
# comment in shadcn.css for why). That means Tailwind's own built-in `animate-*`
# utility also matches them and contributes a second `animation:` declaration
# to the same compiled rule, after this one, resetting `animation-duration`
# regardless of `prefers-reduced-motion`. `!important` on the override is what
# survives that collision. So this spec asserts the `!important` is present on
# those two, not merely that a `@media` block with the right selector exists —
# a `@media` block missing `!important` looks identical to a working one by
# inspection; only the rendered duration tells them apart, which is exactly
# how this shipped broken once already.
#
# File reading, not a browser — but it does not trust whatever
# `tailwindcss:build` last left on disk on its own. The first version of this
# spec asserted the bundle's mtime was newer than shadcn.css's, and that went
# red on a comment-only source edit that did not change the compiled output at
# all: Tailwind's CLI skips rewriting the file when the result would be
# byte-identical to what is already there, so the bundle's mtime does not
# reliably track "was this produced from the current source". Rebuilding
# removes the question rather than trying to detect it.
#
# The rebuild itself lives in `spec_helper.rb`'s `before(:suite)` hook, not
# here — see the comment there for why it runs once for the whole suite rather
# than once per file. This spec only reads the bundle that hook already built.
RSpec.describe "reduced motion in the compiled bundle" do
  root = Pathname(__dir__).join("..")
  dummy = root.join("test/dummy")
  bundle_path = dummy.join("app/assets/builds/tailwind.css")

  # Whether the utility's reduced-motion override needs `!important` to survive
  # the collision described above — true only for the two names that are also
  # `--animate-*` theme keys.
  needs_important = {
    "animate-in" => false,
    "animate-out" => false,
    "animate-accordion-up" => true,
    "animate-accordion-down" => true
  }.freeze

  # The exact classes the components apply, so a new variant shape gets picked
  # up automatically rather than drifting from a hand-maintained list.
  #
  # Reading Ruby text and not parsing it, so a comment that quotes one of these
  # class names mints an example for a class nothing renders. Left that way on
  # purpose: an over-broad scan fails loudly, naming the token it could not
  # find in the bundle, while a scan narrow enough to miss a real class turns
  # every example below green without asserting anything — the failure
  # `.claude/docs/decisions/03-testing.md` records happening twice already.
  classes = Dir[root.join("app/components/**/*.rb")].flat_map do |file|
    File.read(file).scan(%r{[\w\[\]=:/.^-]*animate-(?:in|out|accordion-up|accordion-down)})
  end.uniq.sort

  # This repo only ever pairs these utilities with a bare class or a
  # `data-[state=X]:` variant (confirmed by the scan above) — it does not
  # attempt to handle other variant shapes.
  escape = ->(value) { value.gsub(%r{[\[\]=/:^]}) { |char| "\\#{char}" } }

  # Two shapes this cannot reconstruct, and does not try to. A variant chain
  # naming a group compiles to `:is(:where(.group\/name)[attr=value] *)`, and an
  # attribute *prefix* match to `[data-motion^=...]`; both are Tailwind's own
  # syntax, and writing them out here would be asserting a guess about the
  # compiler rather than about this gem. For those, the assertion is that the
  # class itself appears inside a reduced-motion block with the collapse —
  # per usage, exactly as for the shapes below, and without inventing the
  # selector around it.
  reconstructable = ->(token) { !token.include?("/") && !token.include?("^") }

  compiled_selector = lambda do |token|
    next ".#{token}" unless token.include?(":")

    variant, utility = token.split(":", 2)
    state = variant[/\Adata-\[state=(\w+)\]\z/, 1]
    raise "unhandled variant shape for reduced_motion_spec: #{variant.inspect}" unless state

    escaped_variant = variant.gsub(/[\[\]=]/) { |char| "\\#{char}" }
    ".#{escaped_variant}\\:#{utility}[data-state=#{state}]"
  end

  # Without this, a broken scan pattern makes every example below vacuously
  # green — `parity_spec.rb` and `stimulus_contract_spec.rb` both went green
  # this way once, see `.claude/docs/decisions/03-testing.md`.
  it "found classes to check" do
    expect(classes).not_to be_empty, "no animate-in/animate-out/animate-accordion-* " \
                                      "classes found under app/components"
  end

  classes.each do |token|
    it "collapses `#{token}` under reduced motion" do
      unless reconstructable.call(token)
        css = bundle_path.read
        pattern = /@media \(prefers-reduced-motion:reduce\)\{\.#{Regexp.escape(escape.call(token))}[^{]*\{animation-duration:\.01ms/

        expect(css).to match(pattern), "no reduced-motion collapse compiled for `#{token}`"
        next
      end

      selector = compiled_selector.call(token)
      important = needs_important.fetch(token.split(":").last)
      css = bundle_path.read
      # Extracted first and compared with `eq`, rather than asserting
      # `include` against the whole bundle, so a failure prints this one rule
      # instead of the entire compiled file.
      actual = css[/@media \(prefers-reduced-motion:reduce\)\{#{Regexp.escape(selector)}\{[^}]*\}/]
      expected = "@media (prefers-reduced-motion:reduce){#{selector}{animation-duration:.01ms" \
                 "#{important ? '!important' : ''}}"

      expect(actual).to eq(expected)
    end
  end

  # The Drawer is outside the scan above and cannot be brought into it: its
  # entrance is a plain CSS animation on `[data-vaul-drawer]` rather than a
  # Tailwind `animate-*` class, because vaul's own stylesheet is where it comes
  # from and `drawer.tsx` carries no animation class at all. Nothing scanning
  # `app/components` can find it, so it is named here.
  #
  # Both properties, not one: the panel's entrance is an `animation` and its
  # spring-back is a `transition`, and collapsing only the first would leave a
  # released drag gliding for half a second under reduced motion.
  it "collapses the drawer's animation and its spring-back" do
    rule = bundle_path.read[/@media \(prefers-reduced-motion:reduce\)\{\[data-vaul-drawer\]\{[^}]*\}/]

    expect(rule).to include("transition-duration:.01ms").and include("animation-duration:.01ms")
  end
end
