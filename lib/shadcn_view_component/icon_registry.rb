# frozen_string_literal: true

module ShadcnViewComponent
  # Backs `Shadcn::Icon.register` / `.registered`. Deliberately outside
  # `app/components`, which Rails reloads in development: a hash living on
  # the `Shadcn::Icon` module object would be discarded with it on the next
  # code reload, silently un-registering every icon a host added at boot.
  # `lib/` is not reloaded, so this survives.
  module IconRegistry
    def self.registered
      @registered ||= {}
    end

    def self.register(name, path)
      registered[name.to_s] = path
    end
  end
end
