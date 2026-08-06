# frozen_string_literal: true

module Shadcn
  module ModeToggle
    # Port of registry/new-york-v4/examples/mode-toggle.tsx — the dropdown
    # shadcn documents for switching between light, dark and system.
    #
    # In React the items call next-themes' `setTheme`; here they hand the mode
    # to the `shadcn--theme` Stimulus controller wrapping them.
    class Component < ApplicationViewComponent
      SUN_CLASSES = "h-[1.2rem] w-[1.2rem] scale-100 rotate-0 transition-all " \
                    "dark:scale-0 dark:-rotate-90"

      MOON_CLASSES = "absolute h-[1.2rem] w-[1.2rem] scale-0 rotate-90 transition-all " \
                     "dark:scale-100 dark:rotate-0"

      MODES = %w[light dark system].freeze

      slot_name :"mode-toggle"

      attr_reader :variant, :align

      def initialize(variant: :outline, align: :end, **attributes)
        @variant = variant&.to_sym || :outline
        @align = align&.to_sym || :end
        super(**attributes)
      end

      def element_attributes(**defaults)
        super(**{
          style: merged_style(CONTENTS_STYLE),
          "data-controller" => "shadcn--theme"
        }.merge(defaults))
      end

      def call
        render_element(body: menu)
      end

      private

      def menu
        render(DropdownMenu::Component.new(align:)) do |dropdown|
          dropdown.with_trigger(class: trigger_classes) { trigger_content }
          dropdown.with_menu_content { items }
        end
      end

      def trigger_classes
        Button::Component.variant_classes(variant:, size: :icon)
      end

      def trigger_content
        safe_join([
          render(Icon::Component.new("sun", class: SUN_CLASSES)),
          render(Icon::Component.new("moon", class: MOON_CLASSES)),
          tag.span(shadcn_t("theme.toggle"), class: "sr-only")
        ])
      end

      def items
        safe_join(MODES.map { |mode| item(mode) })
      end

      # Only the extra action goes here: the item already carries the dropdown's
      # own, and `data-action` is concatenated rather than replaced.
      def item(mode)
        render(DropdownMenu::Item::Component.new(
          "data-mode": mode,
          "data-action": "click->shadcn--theme#setMode"
        )) { shadcn_t("theme.#{mode}") }
      end
    end
  end
end
