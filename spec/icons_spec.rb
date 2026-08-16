# frozen_string_literal: true

require "spec_helper"

# What is bundled and what is drawn have to be the same set, and nothing else
# in the suite can see that: an icon nobody renders costs a host bytes forever,
# and an icon a component renders but the gem does not bundle takes the page
# down in development — `Icon::Component` raises rather than leaving a gap.
#
# It is also what the prose could not keep: the README said eleven of what were
# twenty-two, because a number in a sentence has nothing checking it.
#
# **The blind spot**, named rather than papered over: a name built at runtime is
# invisible here. `calendar/component.rb` renders
# `"chevron-#{direction == :previous ? 'left' : 'right'}"`, and this spec sees
# neither half. Previews are excluded on purpose — they are a gallery, and the
# dummy registers the six icons they ask for the way any host would.
RSpec.describe "the bundled icons" do
  components = (Dir[ShadcnViewComponent::Engine.root.join("app/components/**/*.rb")] +
                Dir[ShadcnViewComponent::Engine.root.join("app/components/**/*.html.erb")])
    .reject { |file| file.include?("/previews/") || file.end_with?("preview.rb") }

  sources = components.map { |file| File.read(file) }.join("\n")
  bundled = ShadcnViewComponent::Icons::PATHS.keys

  # `Icon::Component.new("chevron-down")`, with the closing quote, so an
  # interpolated name is skipped rather than half-matched.
  drawn = sources.scan(/Icon::Component\.new\(\s*[:"]([a-z0-9-]+)"/).flatten
                 .map { |name| ShadcnViewComponent::IconRegistry.canonical(name) }.uniq

  it "draws only icons it bundles" do
    expect(drawn - bundled).to be_empty
  end

  # The other direction, which is the one that rots: a component stops using an
  # icon and the drawing stays behind. Matched as a bare string, since the six
  # the toaster and the spinner name go through a constant rather than a
  # literal call.
  it "bundles only icons it draws" do
    unused = bundled.reject { |name| sources.include?(%("#{name}")) }

    expect(unused).to be_empty
  end

  # `rake icons:build` reads the vendored SVGs; every one of them has to end up
  # in the registry, or the generator dropped one silently.
  it "has a vendored SVG behind every drawing" do
    files = Dir[ShadcnViewComponent::Engine.root.join("vendor/lucide/icons/*.svg")]

    expect(files.map { |file| File.basename(file, ".svg") }.sort).to eq(bundled.sort)
  end

  # A sentence saying "eleven" is what started this. If the README wants to
  # give a number, the number has to be checked like anything else.
  it "is counted correctly by the README" do
    readme = File.read(ShadcnViewComponent::Engine.root.join("README.md"))

    expect(readme).to include("#{bundled.size} lucide icons are bundled")
  end
end
