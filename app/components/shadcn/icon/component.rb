# frozen_string_literal: true

module Shadcn
  module Icon
    # Inline replacement for the `lucide-react` icons the components import.
    #
    #   <%= render Shadcn::Icon::Component.new(:"chevron-down", class: "size-4") %>
    #
    # Emits the same SVG lucide does — 24×24 viewBox, `currentColor` stroke,
    # `lucide lucide-<name>` classes — so the `[&_svg:not([class*='size-'])]:size-4`
    # rules on the surrounding components behave identically.
    class Component < ApplicationViewComponent
      # Only the icons referenced by the ported components are bundled.
      PATHS = {
        "check" => %(<path d="M20 6 9 17l-5-5"/>),
        "chevron-down" => %(<path d="m6 9 6 6 6-6"/>),
        "chevron-left" => %(<path d="m15 18-6-6 6-6"/>),
        "chevron-right" => %(<path d="m9 18 6-6-6-6"/>),
        "chevron-up" => %(<path d="m18 15-6-6-6 6"/>),
        "circle" => %(<circle cx="12" cy="12" r="10"/>),
        "loader-circle" => %(<path d="M21 12a9 9 0 1 1-6.219-8.56"/>),
        "ellipsis" => %(<circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/>) +
                      %(<circle cx="5" cy="12" r="1"/>),
        "moon" => %(<path d="M20.985 12.486a9 9 0 1 1-9.473-9.472c.405-.022.617.46.402.803a6 6 ) +
                  %(0 0 0 8.268 8.268c.344-.215.825-.004.803.401"/>),
        "sun" => %(<circle cx="12" cy="12" r="4"/><path d="M12 2v2"/><path d="M12 20v2"/>) +
                 %(<path d="m4.93 4.93 1.41 1.41"/><path d="m17.66 17.66 1.41 1.41"/>) +
                 %(<path d="M2 12h2"/><path d="M20 12h2"/><path d="m6.34 17.66-1.41 1.41"/>) +
                 %(<path d="m19.07 4.93-1.41 1.41"/>),
        "x" => %(<path d="M18 6 6 18"/><path d="m6 6 12 12"/>)
      }.freeze

      # lucide-react aliases kept so call sites read like the TSX imports.
      ALIASES = {
        "loader-2" => "loader-circle",
        "more-horizontal" => "ellipsis"
      }.freeze

      SVG_ATTRIBUTES = {
        "xmlns" => "http://www.w3.org/2000/svg",
        "width" => "24",
        "height" => "24",
        "viewBox" => "0 0 24 24",
        "fill" => "none",
        "stroke" => "currentColor",
        "stroke-width" => "2",
        "stroke-linecap" => "round",
        "stroke-linejoin" => "round"
      }.freeze

      default_tag :svg

      def initialize(name, **attributes)
        @name = ALIASES.fetch(name.to_s, name.to_s)
        raise ArgumentError, "unknown lucide icon: #{name}" unless PATHS.key?(@name)

        super(**attributes)
      end

      attr_reader :name

      def call
        render_element(body: PATHS.fetch(name).html_safe)
      end

      def element_attributes(**defaults)
        super(**SVG_ATTRIBUTES.merge(defaults))
      end

      def css_classes(extra = nil)
        ShadcnViewComponent.cn("lucide", "lucide-#{name}", extra)
      end
    end
  end
end
