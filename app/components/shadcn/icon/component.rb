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
      # The drawings live in `vendor/lucide/icons` as the files lucide
      # publishes, and `rake icons:build` turns them into
      # `ShadcnViewComponent::Icons::PATHS`. They used to be typed into this
      # file by hand, which went exactly as that always goes: the count in the
      # README said eleven of twenty-two, and `search` had been drawn from an
      # older lucide — a magnifier with a shorter handle than the one every
      # other icon in the set was drawn with.
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
        # Resolved through the registry, which owns the alias table: a host
        # registering `"more-horizontal"` and this rendering `"ellipsis"` have
        # to meet somewhere, and the file that stores the drawings is the only
        # place both can.
        @name = ShadcnViewComponent::IconRegistry.canonical(name)

        # Loud where it can be fixed, silent where it cannot. An icon is
        # decorative, and a gem should not be able to take down a page in an
        # application it has never seen — the same trade Rails makes with a
        # missing translation.
        raise ArgumentError, "unknown lucide icon: #{name}" if path.nil? && Rails.env.local?

        super(**attributes)
      end

      attr_reader :name

      # The registry is read first so a host can replace one of the bundled
      # eleven and not only add a twelfth. The other order ignored
      # `register("check", …)` in silence — nothing raised, nothing logged, the
      # gem's own tick still rendering — which leaves a host staring at an icon
      # that will not change with no way to find out why.
      def path
        @path ||= Shadcn::Icon.registered[name] || ShadcnViewComponent::Icons::PATHS[name]
      end

      def call
        return "".html_safe if path.nil?

        render_element(body: path.html_safe)
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
