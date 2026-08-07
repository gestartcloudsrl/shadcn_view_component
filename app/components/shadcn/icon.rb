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

    # The ported components import eleven lucide icons; lucide has about 1,500.
    # A host that needs another registers its path once, at boot.
    def self.register(name, path)
      ShadcnViewComponent::IconRegistry.register(name, path)
    end
  end
end
