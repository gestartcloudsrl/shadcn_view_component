# frozen_string_literal: true

require "spec_helper"
require "tailwindcss/ruby"
# `rails/generators` before the generator itself: its own `require
# "rails/generators/base"` is not enough on its own, and the failure names
# `Rails::Generators::Actions` rather than anything about generators being
# unloaded.
require "rails/generators"
require "generators/shadcn_view_component/install/install_generator"

# The install generator writes three lines that name paths into this gem, and
# nothing in the suite used to read them. Two of the three did not work: it
# wrote `@import "shadcn.css"`, which looks like an asset-pipeline path and is
# not one — `tailwindcss-rails` runs the CLI with `-i` and `-o` and no load
# path, so a bare name resolves the way Node resolves it, beside the file and
# then in `node_modules`, and a Rails app has neither. Every host running the
# generator got `Can't resolve 'shadcn.css'` and no styles.
#
# It survived because the only application this repo can see does not use those
# lines: the dummy's entrypoint reaches the engine with `../../../../..`, a
# relationship no host has.
#
# So this spec does the one thing that would have caught it — it compiles what
# the generator writes, with the same binary `tailwindcss-rails` runs.
RSpec.describe ShadcnViewComponent::Generators::InstallGenerator do
  subject(:generator) { described_class.new }

  # The dummy is the host here, and the paths the generator writes are relative
  # to the file they land in — so the file has to be written where that file
  # would be.
  let(:entrypoint) { "app/assets/tailwind/application.css" }
  let(:directory) { Rails.root.join(entrypoint).dirname }
  let(:source) { directory.join("generator_check.css") }
  let(:compiled) { Pathname(Dir.tmpdir).join("generator_check_out.css") }

  after { FileUtils.rm_f([ source, compiled ]) }

  def compile
    source.write("@import \"tailwindcss\";\n#{generator.send(:tailwind_block, entrypoint)}")

    # From the application's own directory, the way `tailwindcss-rails` runs
    # it. It decides where to look for classes from there too, so run it
    # anywhere else — the repository root, say — and it finds this gem's
    # components by itself, which would make `@source` look like it worked
    # when it had been deleted.
    system(Tailwindcss::Ruby.executable.to_s, "-i", source.to_s, "-o", compiled.to_s,
           chdir: Rails.root.to_s, out: File::NULL, err: File::NULL)
  end

  it "writes a block Tailwind can compile" do
    expect(compile).to be(true)
  end

  # Three lines, three things to prove, and each fails on its own: a token from
  # `shadcn.css`, a palette from `shadcn-themes.css`, and a class that lives
  # nowhere but in this gem's components, which nothing but `@source` reaches
  # from the application's directory.
  it "pulls in the tokens, the palettes and the components", :aggregate_failures do
    compile
    css = compiled.read

    expect(css).to include("--radius")
    expect(css).to include("theme-blue")
    expect(css).to include("bg-primary")
  end

  # A path that starts at the root of a filesystem is right on the machine that
  # wrote it and wrong on every other, and the CSS is built on all of them. So
  # the common shape — `bundle config set path vendor/bundle`, which is what CI
  # and most containers do — has to come out relative.
  #
  # The dummy is the other shape: this gem is its *parent*, so the generator
  # writes absolute paths there, which is why the rule is asserted on a path
  # rather than on what the dummy happens to produce.
  it "writes a relative path when the gem sits inside the application" do
    bundled = Rails.root.join("vendor/bundle/ruby/3.4.0/gems/shadcn_view_component-0.1.0/app/components")

    expect(generator.send(:path_to, bundled, entrypoint))
      .to eq("../../../vendor/bundle/ruby/3.4.0/gems/shadcn_view_component-0.1.0/app/components")
  end
end
