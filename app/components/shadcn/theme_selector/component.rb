# frozen_string_literal: true

module Shadcn
  module ThemeSelector
    # Port of apps/v4/components/theme-selector.tsx — the select that swaps the
    # colour palette.
    #
    # In React this reads `useThemeConfig()`; here each option hands its value
    # to the `shadcn--theme` Stimulus controller, which swaps the `theme-*`
    # class the way shadcn's `ActiveThemeProvider` does.
    class Component < ApplicationViewComponent
      slot_name :"theme-selector"

      style do
        base { "flex items-center gap-2" }
      end

      attr_reader :themes, :value

      # @param themes [Array<Hash>] entries from ShadcnViewComponent::Themes
      # @param value [String] the palette currently applied
      def initialize(themes: ShadcnViewComponent::Themes::BASE_COLORS,
                     value: ShadcnViewComponent::Themes::DEFAULT,
                     label: nil,
                     **attributes)
        @themes = themes
        @value = value.to_s
        @label = label
        super(**attributes)
      end

      def label
        @label || shadcn_t("theme.label")
      end

      def element_attributes(**defaults)
        super(**{ "data-controller" => "shadcn--theme" }.merge(defaults))
      end

      def call
        render_element(body: safe_join([ hidden_label, select ]))
      end

      private

      def hidden_label
        render(Label::Component.new(for: "theme-selector", class: "sr-only")) { label }
      end

      def select
        render(Select::Component.new(value:, placeholder: "Select a theme")) do |component|
          component.with_trigger(
            id: "theme-selector",
            class: "w-36",
            placeholder: current_title.nil?
          ) do |trigger|
            trigger.with_value(placeholder: "Select a theme") { current_title }
          end
          component.with_select_content { options }
        end
      end

      def current_title
        ShadcnViewComponent::Themes.find(value)&.fetch(:title)
      end

      def options
        render(Select::Group::Component.new) do
          safe_join([ render(Select::Label::Component.new) { label } ] + items)
        end
      end

      def items
        themes.map do |theme|
          render(Select::Item::Component.new(
            value: theme[:name],
            selected: theme[:name] == value,
            "data-action": "click->shadcn--theme#setTheme"
          )) { theme[:title] }
        end
      end
    end
  end
end
