# frozen_string_literal: true

module Shadcn
  # `Icon::Component`'s registry, kept in this sibling file — the same split
  # every other family uses between its shared module and `component.rb` —
  # so `Shadcn::Icon.register` is reachable from a host's initializer without
  # first loading `Icon::Component` to trigger it.
  module Icon
    # Icons a host has added. Kept separate from PATHS so the bundled set stays
    # a frozen literal and a host cannot redefine one by accident.
    def self.registered
      @registered ||= {}
    end

    # The ported components import eleven lucide icons; lucide has about 1,500.
    # A host that needs another registers its path once, at boot.
    def self.register(name, path)
      registered[name.to_s] = path
    end
  end
end
