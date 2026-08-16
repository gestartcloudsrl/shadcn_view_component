# frozen_string_literal: true

require_relative "../shadcn_view_component/icon_registry"

# Constants *and* methods declared in a rake namespace land on Object, and
# `themes.rake` is already there with `ROOT`, `registry` and friends — so
# everything here carries a name of its own. Called `registry`, this file's
# generator was shadowed by the theme one and the first run built a theme
# registry out of icons.
namespace :icons do
  ICONS_BANNER = <<~TEXT
    Generated from the vendored lucide SVGs (`vendor/lucide/icons`, taken from
    lucide-static at the version in `vendor/lucide/REVISION`) — do not edit by
    hand, run `rake icons:build`.
  TEXT

  desc "Regenerate the icon drawings from the vendored lucide SVGs"
  task :build do
    root = Pathname(__dir__).join("../..").expand_path
    files = Dir.glob(root.join("vendor/lucide/icons/*.svg")).sort

    raise "no SVGs in vendor/lucide/icons" if files.empty?

    drawings = files.to_h do |file|
      [ File.basename(file, ".svg"), ShadcnViewComponent::IconRegistry.drawing(File.read(file)) ]
    end

    root.join("lib/shadcn_view_component/icons.rb").write(icons_registry(drawings))

    puts "Wrote #{drawings.size} icons."
  end

  # One entry a line, however long the line: this file is read as a diff — a
  # drawing that changed, an icon that arrived — and a string broken across
  # continuations is a diff nobody can read. Rubocop skips it for the same
  # reason it skips the theme registry: the generator is the thing to lint.
  def self.icons_registry(drawings)
    entries = drawings.map { |name, drawing| %(      "#{name}" => %(#{drawing})) }

    <<~RUBY
      # frozen_string_literal: true

      #{ICONS_BANNER.strip.gsub(/^/, '# ').gsub(/^# $/, '#')}
      module ShadcnViewComponent
        module Icons
          PATHS = {
      #{entries.join(",\n")}
          }.freeze
        end
      end
    RUBY
  end
end
