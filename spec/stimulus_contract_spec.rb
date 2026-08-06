# frozen_string_literal: true

require "spec_helper"

# The Ruby and the JavaScript are wired together by bare strings: a component
# writes `data-action="click->shadcn--select#toggle"` and hopes some controller
# defines `toggle`. Rename the method and every Select in the wild breaks with
# nothing failing — rendering still succeeds, the click just does nothing.
#
# This reads the strings the components actually emit and checks the other side
# exists. It is static analysis of the JavaScript, not execution of it: a browser
# test would be stronger, but this closes the largest class of silent breakage
# for very little.
RSpec.describe "Ruby ↔ Stimulus contract" do
  components = Pathname(__dir__).join("../app/components/shadcn")
  controllers = Pathname(__dir__).join("../app/javascript/shadcn/controllers")
  registry = Pathname(__dir__).join("../app/javascript/shadcn/index.js").read

  # shadcn--dropdown-menu => .../dropdown_menu_controller.js
  sources = Dir[controllers.join("*_controller.js")].to_h do |path|
    [ "shadcn--#{File.basename(path, '_controller.js').tr('_', '-')}", File.read(path) ]
  end

  ruby = Dir[components.join("**/*.rb")]
         .reject { |path| File.basename(path) == "preview.rb" }
         .to_h { |path| [ Pathname(path).relative_path_from(components).to_s, File.read(path) ] }

  scan = lambda do |pattern|
    ruby.flat_map { |file, source| source.scan(pattern).map { |captures| [ file, *captures ] } }.uniq
  end

  # Longest first, so `shadcn--toggle-group-type-value` is not read as the
  # `group-type` value of `shadcn--toggle`.
  identifiers = sources.keys.sort_by { |identifier| -identifier.length }
  split = lambda do |attribute|
    identifier = identifiers.find { |candidate| attribute.start_with?("#{candidate}-") }
    identifier && [ identifier, attribute.delete_prefix("#{identifier}-") ]
  end

  used_controllers = scan.call(/"data-controller"\s*=>\s*"(shadcn--[a-z-]+)"/).map(&:last).uniq
  actions = scan.call(/(shadcn--[a-z-]+)#([a-zA-Z]+)/)

  targets = scan.call(/"data-(shadcn--[a-z-]+)-target"\s*=>\s*"(\w+)"/)
  values = scan.call(/"data-(shadcn--[a-z-]+)-value"/).filter_map do |(file, attribute)|
    identifier, value = split.call(attribute)
    identifier && [ file, identifier, value ]
  end

  # Everything below is generated from what the scans found, so a scan that stops
  # matching — a quoting change in the Ruby, a renamed attribute — produces no
  # examples at all and leaves the suite green while proving nothing. These
  # floors are well under the current counts; they are a tripwire, not a target.
  it "found the wiring it is meant to be checking", :aggregate_failures do
    expect(sources.size).to be >= 15, "no controller sources were read"
    expect(used_controllers.size).to be >= 12
    expect(actions.size).to be >= 35
    expect(targets.size).to be >= 25
    expect(values.size).to be >= 40
  end

  describe "controllers" do
    used_controllers.each do |identifier|
      short = identifier.delete_prefix("shadcn--")

      it "#{identifier} has a controller file and is registered", :aggregate_failures do
        expect(sources[identifier]).not_to be_nil, "no #{short}_controller.js"
        expect(registry).to match(/^\s+"?#{Regexp.escape(short)}"?:/),
                            "#{short} is missing from the CONTROLLERS map in index.js"
      end
    end
  end

  describe "actions" do
    actions.each do |(file, identifier, method)|
      it "#{identifier}##{method} exists (#{file})" do
        expect(sources[identifier]).not_to be_nil, "no controller for #{identifier}"
        expect(sources[identifier]).to match(/^\s{2}#{Regexp.escape(method)}\s*\(/),
                                       "#{identifier} defines no #{method}()"
      end
    end
  end

  describe "targets" do
    targets.each do |(file, identifier, target)|
      it "#{identifier} declares the #{target} target (#{file})" do
        declared = sources[identifier].to_s[/static targets = \[(.*?)\]/m].to_s

        expect(declared).to include(%("#{target}")), "#{identifier} declares no #{target} target"
      end
    end
  end

  describe "values" do
    values.each do |(file, identifier, value)|
      camel = value.split("-").each_with_index.map { |part, i| i.zero? ? part : part.capitalize }.join

      it "#{identifier} declares the #{camel} value (#{file})" do
        declared = sources[identifier].to_s[/static values = \{(.*?)^  \}/m].to_s

        expect(declared).to match(/\b#{Regexp.escape(camel)}\s*:/), "#{identifier} declares no #{camel} value"
      end
    end
  end
end
