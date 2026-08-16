# frozen_string_literal: true

module Shadcn
  # `Shadcn::Icon.register` / `.registered`, kept in this sibling file — the
  # same split every other family uses between its shared module and
  # `component.rb` — so `Shadcn::Icon` resolves without first loading
  # `Icon::Component`, and these read naturally from a view or another
  # component without going through it. That does *not* extend to a host's
  # initializer: no autoloadable constant, this one included, resolves there
  # — `ShadcnViewComponent::IconRegistry`, required directly in
  # `lib/shadcn_view_component.rb`, is the entry point the README documents
  # for that case.
  #
  # The storage itself lives in `ShadcnViewComponent::IconRegistry`, under
  # `lib/`, rather than on this module: `app/components` reloads in
  # development, and a hash held here would be discarded — and every
  # registered icon un-registered — on the next code reload.
  module Icon
    def self.registered
      ShadcnViewComponent::IconRegistry.registered
    end

    # Every lucide alias this gem knows — `more-horizontal` for `ellipsis`,
    # `loader-2` for `loader-circle`. Registering under either spelling reaches
    # both, because the registry stores one entry per icon rather than one per
    # name.
    def self.aliases
      ShadcnViewComponent::IconRegistry::ALIASES
    end

    # The ported components import a couple of dozen lucide icons; lucide has
    # about 1,500. The exact set is `ShadcnViewComponent::Icons::PATHS`, and a
    # spec keeps it equal to what the components render — no number is written
    # in prose here, because that is what went stale last time.
    # A host reaches this pair from a view, a component or anywhere else
    # autoloading has already run — not from an initializer, which is what
    # `ShadcnViewComponent::IconRegistry` is for. Registering a bundled name
    # replaces it.
    def self.register(name, path)
      ShadcnViewComponent::IconRegistry.register(name, path)
    end
  end
end
