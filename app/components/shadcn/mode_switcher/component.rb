# frozen_string_literal: true

module Shadcn
  module ModeSwitcher
    # Port of apps/v4/components/mode-switcher.tsx — the single button used in
    # shadcn's own site header, which flips straight between light and dark
    # rather than offering the three-way menu.
    #
    # The icon is the same half-filled circle upstream draws inline.
    class Component < ApplicationViewComponent
      ICON = %(<path stroke="none" d="M0 0h24v24H0z" fill="none"/>) +
             %(<path d="M12 12m-9 0a9 9 0 1 0 18 0a9 9 0 1 0 -18 0"/>) +
             %(<path d="M12 3l0 18"/><path d="M12 9l4.65 -4.65"/>) +
             %(<path d="M12 14.3l7.37 -7.37"/><path d="M12 19.6l8.85 -8.85"/>)

      ICON_ATTRIBUTES = {
        "xmlns" => "http://www.w3.org/2000/svg",
        "width" => "24",
        "height" => "24",
        "viewBox" => "0 0 24 24",
        "fill" => "none",
        "stroke" => "currentColor",
        "stroke-width" => "2",
        "stroke-linecap" => "round",
        "stroke-linejoin" => "round",
        "class" => "size-4.5"
      }.freeze

      slot_name :"mode-switcher"

      attr_reader :variant

      def initialize(variant: :ghost, **attributes)
        @variant = variant&.to_sym || :ghost
        super(**attributes)
      end

      def element_attributes(**defaults)
        super(**{
          style: merged_style(CONTENTS_STYLE),
          "data-controller" => "shadcn--theme"
        }.merge(defaults))
      end

      def call
        render_element(body: button)
      end

      private

      def button
        render(Button::Component.new(
          variant:,
          size: :icon,
          class: "group/toggle extend-touch-target size-8",
          "data-action": "shadcn--theme#toggle"
        )) do
          safe_join([ tag.svg(raw(ICON), **ICON_ATTRIBUTES), label ])
        end
      end

      def label
        tag.span(shadcn_t("theme.toggle"), class: "sr-only")
      end
    end
  end
end
