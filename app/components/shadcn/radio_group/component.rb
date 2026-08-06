# frozen_string_literal: true

module Shadcn
  module RadioGroup
    # Port of registry/new-york-v4/ui/radio-group.tsx
    class Component < ApplicationViewComponent
      renders_many :items, "Shadcn::RadioGroup::Item::Component"

      slot_name :"radio-group"

      style do
        base { "grid gap-3" }
      end

      attr_reader :name, :value, :disabled

      def initialize(name: nil, value: nil, disabled: false, **attributes)
        @name = name
        @value = value.to_s
        @disabled = disabled
        super(**attributes)
      end

      def element_attributes(**defaults)
        super(**{
          role: "radiogroup",
          "aria-required" => nil,
          "data-disabled" => (true if disabled),
          "data-controller" => "shadcn--radio-group",
          "data-shadcn--radio-group-value-value" => value,
          "data-shadcn--radio-group-disabled-value" => disabled
        }.merge(defaults))
      end

      def call
        render_element(body: safe_join([ items, content, hidden_input ].flatten.compact))
      end

      private

      # Radix mirrors the selection into a hidden input so the group submits
      # with the form.
      def hidden_input
        return unless name

        tag.input(
          type: "hidden",
          name: name,
          value: value,
          "data-shadcn--radio-group-target": "input"
        )
      end
    end
  end
end
