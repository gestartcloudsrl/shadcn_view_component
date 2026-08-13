ENV["RAILS_ENV"] ||= "test"

require File.expand_path("../test/dummy/config/environment", __dir__)
require "rspec/rails"
require "view_component/test_helpers"
require "capybara/rspec"
require "nokogiri"

require_relative "support/component_helpers"
require_relative "support/system"

RSpec.configure do |config|
  # `travel_to` for the specs that render a date: the calendar draws today, so
  # its snapshots and its system examples are only deterministic with the clock
  # held still. Frozen where it is needed rather than everywhere — the drawer
  # and the toaster run on real timers.
  config.include ActiveSupport::Testing::TimeHelpers

  config.include ViewComponent::TestHelpers, type: :component
  config.include Capybara::RSpecMatchers, type: :component
  config.include ComponentHelpers, type: :component

  config.define_derived_metadata(file_path: %r{/spec/components/}) do |metadata|
    metadata[:type] = :component
  end

  config.define_derived_metadata(file_path: %r{/spec/system/}) do |metadata|
    metadata[:type] = :system
  end

  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed

  # The system and reduced-motion specs read the compiled Tailwind bundle, and
  # `config.order = :random` means the spec that used to build it could run
  # after the specs that depend on it — asserting against whatever was last
  # left on disk.
  #
  # Deliberately paid on every invocation, including one that runs a single
  # component spec: about 1.5s, in exchange for no tag to remember and no
  # ordering to reason about. Do not move it back into a per-file hook.
  #
  # A hook, not code that runs while specs are still loading: a build there
  # once failed and took down all 546 examples with "0 examples, 0 failures,
  # 1 error occurred outside of examples" — none of them able to say why.
  config.before(:suite) do
    dummy = Pathname(__dir__).join("../test/dummy")
    system(dummy.join("bin/rails").to_s, "tailwindcss:build", chdir: dummy.to_s, exception: true)
  end
end
