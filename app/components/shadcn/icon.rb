# frozen_string_literal: true

module Shadcn
  # `Shadcn::Icon.register` / `.registered`, kept in this sibling file — the
  # same split every other family uses between its shared module and
  # `component.rb` — so the constant is reachable from a host's initializer
  # without first loading `Icon::Component` to trigger it.
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
