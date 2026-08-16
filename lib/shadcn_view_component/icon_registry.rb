# frozen_string_literal: true

module ShadcnViewComponent
  # Backs `Shadcn::Icon.register` / `.registered`. Deliberately outside
  # `app/components`, which Rails reloads in development: a hash living on
  # the `Shadcn::Icon` module object would be discarded with it on the next
  # code reload, silently un-registering every icon a host added at boot.
  # `lib/` is not reloaded, so this survives.
  module IconRegistry
    # lucide-react's own aliases, kept so call sites read like the TSX imports
    # — `Icon::Component.new("more-horizontal")` is what `pagination.tsx`
    # writes. They live here rather than beside the drawings because *this* is
    # the file that has to know about them: a host registering
    # `"more-horizontal"` and the gem rendering `"ellipsis"` are the same icon,
    # and until they were resolved in one place the registration was stored
    # under a key nothing ever looked up.
    ALIASES = {
      "loader-2" => "loader-circle",
      "more-horizontal" => "ellipsis"
    }.freeze

    def self.registered
      @registered ||= {}
    end

    # Stored under the canonical name, so registering under either spelling
    # reaches every call site that uses either — one icon, one entry.
    def self.register(name, path)
      registered[canonical(name)] = path
    end

    def self.canonical(name)
      ALIASES.fetch(name.to_s, name.to_s)
    end

    # Register every `*.svg` in a directory, under its own basename. This is
    # how a host adds icons the gem does not bundle: download the SVGs it wants
    # — lucide publishes them as files, and so does everyone else — drop them
    # in a directory and point here from an initializer.
    #
    #   ShadcnViewComponent::IconRegistry.load_directory(
    #     Rails.root.join("app/assets/icons")
    #   )
    #
    # It reads files, so it is the caller who decides when: an initializer
    # pays once at boot. Nothing in the gem calls it — the bundled icons are
    # generated into `Icons::PATHS` at build time, so a host that adds none
    # reads no files at all.
    def self.load_directory(path)
      Dir.glob(File.join(path, "*.svg")).sort.each do |file|
        register(File.basename(file, ".svg"), drawing(File.read(file)))
      end
    end

    # What a `<svg>` element contains, with the whitespace its author used to
    # lay it out taken back out. The outer element is deliberately dropped:
    # `Icon::Component` renders that itself, with lucide's own attributes and
    # `lucide lucide-<name>` classes, so a file's own `<svg …>` would arrive as
    # a second opinion about the thing the component already owns.
    def self.drawing(source)
      inside = source[%r{<svg\b[^>]*>(.*)</svg>}m, 1].to_s

      inside.gsub(/>\s+</, "><").gsub(%r{\s+/>}, "/>").strip
    end
  end
end
