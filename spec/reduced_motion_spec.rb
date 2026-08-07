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
# File reading, not a browser — but it rebuilds the bundle itself first rather
# than trusting whatever `tailwindcss:build` last left on disk. The first
# version of this spec asserted the bundle's mtime was newer than shadcn.css's,
# and that went red on a comment-only source edit that did not change the
# compiled output at all: Tailwind's CLI skips rewriting the file when the
# result would be byte-identical to what is already there, so the bundle's
# mtime does not reliably track "was this produced from the current source".
# Rebuilding removes the question rather than trying to detect it — cheap
# enough to not need the shortcut (`tailwindcss:build` reports well under a
# second for this bundle), and correctness here is the entire point of the
# spec. Run once, directly in the `describe` body rather than a `before` hook
# — the same place `classes` below reads the filesystem — since it is a
# once-per-file precondition, not per-example state: it is idempotent, same
# source on disk always produces the same output, so it carries none of the
# leaked-mutable-state risk `before(:context)` is normally avoided for here.
RSpec.describe "reduced motion in the compiled bundle" do
  root = Pathname(__dir__).join("..")
  dummy = root.join("test/dummy")
  bundle_path = dummy.join("app/assets/builds/tailwind.css")

  system(dummy.join("bin/rails").to_s, "tailwindcss:build", chdir: dummy.to_s, exception: true)

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
  classes = Dir[root.join("app/components/**/*.rb")].flat_map do |file|
    File.read(file).scan(/[\w\[\]=:-]*animate-(?:in|out|accordion-up|accordion-down)/)
  end.uniq.sort

  # Without this, a broken scan pattern makes every example below vacuously
  # green — `parity_spec.rb` and `stimulus_contract_spec.rb` both went green
  # this way once, see `.claude/docs/decisions/03-testing.md`.
  it "found classes to check" do
    expect(classes).not_to be_empty, "no animate-in/animate-out/animate-accordion-* " \
                                      "classes found under app/components"
  end

  # This repo only ever pairs these utilities with a bare class or a
  # `data-[state=X]:` variant (confirmed by the scan above) — it does not
  # attempt to handle other variant shapes.
  compiled_selector = lambda do |token|
    next ".#{token}" unless token.include?(":")

    variant, utility = token.split(":", 2)
    state = variant[/\Adata-\[state=(\w+)\]\z/, 1]
    raise "unhandled variant shape for reduced_motion_spec: #{variant.inspect}" unless state

    escaped_variant = variant.gsub(/[\[\]=]/) { |char| "\\#{char}" }
    ".#{escaped_variant}\\:#{utility}[data-state=#{state}]"
  end

  classes.each do |token|
    utility = token.split(":").last
    selector = compiled_selector.call(token)
    important = needs_important.fetch(utility)

    it "collapses `#{token}` under reduced motion" do
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
end
