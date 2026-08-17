# frozen_string_literal: true

require "rails/generators/base"

module ShadcnViewComponent
  module Generators
    # `bin/rails generate shadcn_view_component:install`
    #
    # Wires the gem into a host app. The part worth automating is every line
    # that names a path into this gem: they have to point inside whatever
    # directory bundler put us in, and that differs between a system gem,
    # `bundle config set path`, a `path:` checkout and a `git:` source.
    #
    # All three lines, not just `@source`. This generator used to write
    # `@import "shadcn.css"`, which reads like an asset-pipeline path and is
    # not one: `tailwindcss-rails` runs the CLI with `-i` and `-o` and no load
    # path, so the CLI resolves a bare name the way Node does — beside the file,
    # then `node_modules` — and a Rails app has neither. It stopped the build
    # with `Can't resolve 'shadcn.css'`. The dummy never showed it because its
    # own entrypoint reaches the engine with `../../../../..`, which is a
    # relationship no host has.
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      # Where a Stimulus application is in scope. `controllers/index.js` is the
      # file importmap-rails generates, and it opens with
      # `import { application } from "controllers/application"` — so a line
      # appended there can register onto the app's own instance.
      #
      # `app/javascript/application.js` is not that file. It imports
      # `"controllers"` for the side effect and defines no `application`
      # binding, which is where this generator used to append: a stock Rails 8
      # app got `ReferenceError: application is not defined`, no controllers
      # registered, and every dialog, select and menu inert — with the CSS
      # working, so it looked installed.
      JAVASCRIPT_ENTRYPOINT = "app/javascript/controllers/index.js"

      TAILWIND_ENTRYPOINTS = [
        "app/assets/tailwind/application.css",
        "app/assets/stylesheets/application.tailwind.css",
        "app/assets/stylesheets/application.css"
      ].freeze

      def add_tailwind_imports
        entrypoint = TAILWIND_ENTRYPOINTS.find { |path| File.exist?(Rails.root.join(path)) }

        unless entrypoint
          say_status :skip, "no Tailwind entrypoint found; add the block below yourself", :yellow
          say "(paths are written for #{TAILWIND_ENTRYPOINTS.first}; adjust them if yours sits elsewhere)"
          say tailwind_block(TAILWIND_ENTRYPOINTS.first)
          return
        end

        if File.read(Rails.root.join(entrypoint)).include?("shadcn.css")
          say_status :identical, entrypoint
          return
        end

        append_to_file entrypoint, "\n#{tailwind_block(entrypoint)}"
      end

      def add_javascript
        return say_status :skip, "no importmap; import \"shadcn\" yourself", :yellow unless importmap?

        unless File.exist?(Rails.root.join(JAVASCRIPT_ENTRYPOINT))
          say_status :skip, "#{JAVASCRIPT_ENTRYPOINT} not found; register the controllers yourself", :yellow
          say javascript_block
          return
        end

        if File.read(Rails.root.join(JAVASCRIPT_ENTRYPOINT)).include?("registerShadcnControllers")
          return say_status :identical, JAVASCRIPT_ENTRYPOINT
        end

        append_to_file JAVASCRIPT_ENTRYPOINT, "\n#{javascript_block}"
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
      def gem_root
        Pathname(ShadcnViewComponent::Engine.root)
      end

      # Relative to the file the line is written into, whenever this gem sits
      # inside the application — which is what `bundle config set path
      # vendor/bundle` does, and what CI and most containers do. An absolute
      # path is correct only on the machine that generated it, and the CSS is
      # built on every machine.
      #
      # Computed against the entrypoint rather than against a fixed depth: the
      # three conventional locations happen to be three deep today, and a
      # generator that would break on the fourth is a generator waiting.
      def path_to(target, entrypoint)
        return target.to_s unless inside_application?(target)

        target.relative_path_from(Rails.root.join(entrypoint).dirname).to_s
      end

      # A relative path is worth having only while it stays inside the
      # application: between two unrelated trees — a system gem, a sibling
      # checkout — it encodes the distance between them, which is as personal
      # to one machine as an absolute path and harder to read.
      def inside_application?(target)
        !target.relative_path_from(Rails.root).to_s.start_with?("..")
      rescue ArgumentError
        # Different volumes: no relative path exists at all.
        false
      end

      # `application` is the binding `controllers/index.js` already has. Adding
      # an `Application.start()` here instead would start a *second* Stimulus
      # instance beside the app's own, and two instances fight over every
      # element they both claim.
      def javascript_block
        <<~JS
          import { registerShadcnControllers } from "shadcn"
          registerShadcnControllers(application)
        JS
      end

      def tailwind_block(entrypoint)
        stylesheets = gem_root.join("app/assets/stylesheets")

        <<~CSS
          /* shadcn_view_component */
          @import "#{path_to(stylesheets.join('shadcn.css'), entrypoint)}";
          @import "#{path_to(stylesheets.join('shadcn-themes.css'), entrypoint)}";
          @source "#{path_to(gem_root.join('app/components'), entrypoint)}";
        CSS
      end
    end
  end
end
