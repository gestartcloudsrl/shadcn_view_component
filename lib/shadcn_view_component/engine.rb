module ShadcnViewComponent
  # Rails engine wiring.
  #
  # `app/components` is picked up automatically as an autoload/eager-load root
  # by the `app/{*,*/concerns}` glob every Rails::Engine declares, so
  # `app/components/shadcn/card/component.rb` resolves to `Shadcn::Card::Component`
  # with no extra configuration. Nesting everything under `shadcn/` keeps names
  # such as `Card`, `Table` or `Field` out of the host application's top level,
  # where they would clash with its own models.
  class Engine < ::Rails::Engine
    COMPONENTS_PATH = "app/components".freeze

    # Host apps configure the gem through `config.shadcn_view_component` in
    # their `application.rb`, e.g.
    #
    #     config.shadcn_view_component.cache_size = 50_000
    config.shadcn_view_component = ActiveSupport::OrderedOptions.new

    # Register component previews (sidecar `preview.rb` next to `component.rb`).
    initializer "shadcn_view_component.previews" do |app|
      options = app.config.view_component
      options.previews.paths << root.join(COMPONENTS_PATH).to_s

      ActiveSupport.on_load(:view_component) do
        ViewComponent::Preview.extend ViewComponentContrib::Preview::Sidecarable
      end
    end

    # Build the tailwind-merge instance at boot rather than on the first
    # request: it costs a few milliseconds to construct, and two Puma threads
    # racing on a lazy `||=` would each build one and discard a warm cache.
    initializer "shadcn_view_component.merger" do |app|
      configured = app.config.shadcn_view_component.cache_size
      ShadcnViewComponent.cache_size = configured if configured

      ShadcnViewComponent.build_merger

      # Style blocks are redefined when components reload, so the memoised
      # class strings have to go with them.
      app.config.to_prepare { ShadcnViewComponent.class_cache.clear }
    end

    # Make the theming and form helpers available to the host application's
    # views. The form builder is required here rather than at the top of the gem
    # because it subclasses ActionView's.
    initializer "shadcn_view_component.helpers" do
      ActiveSupport.on_load(:action_view) do
        require "shadcn_view_component/form_builder"
      end

      ActiveSupport.on_load(:action_controller_base) do
        helper ShadcnViewComponent::ThemeHelper
        helper ShadcnViewComponent::FormHelper
      end
    end

    # Expose the bundled stylesheet and Stimulus controllers to the asset pipeline.
    initializer "shadcn_view_component.assets" do |app|
      next unless app.config.respond_to?(:assets)

      app.config.assets.paths << root.join("app/assets/stylesheets")
      app.config.assets.paths << root.join("app/javascript")
    end

    # Make `shadcn/*` importable when the host app uses importmap-rails.
    initializer "shadcn_view_component.importmap", before: "importmap" do |app|
      next unless app.config.respond_to?(:importmap)

      app.config.importmap.paths << root.join("config/importmap.rb")
      app.config.importmap.cache_sweepers << root.join("app/javascript")
    end
  end
end
