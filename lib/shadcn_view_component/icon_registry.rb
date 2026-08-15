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
  end
end
