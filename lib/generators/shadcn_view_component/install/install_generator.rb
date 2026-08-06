# frozen_string_literal: true

require "rails/generators/base"

module ShadcnViewComponent
  module Generators
    # `bin/rails generate shadcn_view_component:install`
    #
    # Wires the gem into a host app. The part worth automating is the Tailwind
    # `@source` line: it has to point at this gem's components inside whatever
    # directory bundler put them in, and that path differs between a system gem,
    # `bundle config set path`, a `path:` checkout and a `git:` source. Hand-
    # written, it is wrong more often than right — and when it is wrong nothing
    # errors, the app just renders unstyled.
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      TAILWIND_ENTRYPOINTS = [
        "app/assets/tailwind/application.css",
        "app/assets/stylesheets/application.tailwind.css",
        "app/assets/stylesheets/application.css"
      ].freeze

      def add_tailwind_imports
        entrypoint = TAILWIND_ENTRYPOINTS.find { |path| File.exist?(Rails.root.join(path)) }

        unless entrypoint
          say_status :skip, "no Tailwind entrypoint found; add the block below yourself", :yellow
          say tailwind_block
          return
        end

        if File.read(Rails.root.join(entrypoint)).include?("shadcn.css")
          say_status :identical, entrypoint
          return
        end

        append_to_file entrypoint, "\n#{tailwind_block}"
      end

      def add_javascript
        return say_status :skip, "no importmap; import \"shadcn\" yourself", :yellow unless importmap?

        entrypoint = "app/javascript/application.js"
        return say_status :skip, "#{entrypoint} not found", :yellow unless File.exist?(Rails.root.join(entrypoint))

        if File.read(Rails.root.join(entrypoint)).include?("registerShadcnControllers")
          return say_status :identical, entrypoint
        end

        append_to_file entrypoint, <<~JS

          import { registerShadcnControllers } from "shadcn"
          registerShadcnControllers(application)
        JS
      end

      def show_layout_hint
        say "\nAdd the theming tags to your layout:", :green
        say <<~ERB
          <head>
            <%= shadcn_theme_script_tag %>
          </head>
          <body class="<%= shadcn_theme_class %>">
        ERB
      end

      private

      def importmap?
        File.exist?(Rails.root.join("config/importmap.rb"))
      end

      # Resolved from the loaded gem spec, so it is correct wherever bundler put
      # us — including a `path:` or `git:` source.
      def gem_components_path
        Pathname(ShadcnViewComponent::Engine.root).join("app/components")
      end

      def tailwind_block
        <<~CSS
          /* shadcn_view_component */
          @import "shadcn.css";
          @import "shadcn-themes.css";
          @source "#{gem_components_path}";
        CSS
      end
    end
  end
end
