# frozen_string_literal: true

module Shadcn
  module ToggleGroup
    # Port of registry/new-york-v4/ui/toggle-group.tsx
    #
    # React passes variant/size/spacing down through context; here the group
    # exposes them to its items through the slot, which is the same idea.
    class Component < ApplicationViewComponent
      renders_many :items, ->(**kwargs, &block) {
        Item::Component.new(variant:, size:, spacing:, **kwargs, &block)
      }

      slot_name :"toggle-group"

      style do
        base {
          "group/toggle-group flex w-fit items-center gap-[--spacing(var(--gap))] rounded-md " \
          "data-[spacing=default]:data-[variant=outline]:shadow-xs"
        }
      end

      attr_reader :type, :variant, :size, :spacing, :value, :name

      def initialize(type: :single, variant: :default, size: :default, spacing: 0,
                     value: nil, name: nil, **attributes)
        @type = type&.to_sym || :single
        @variant = variant&.to_sym || :default
        @size = size&.to_sym || :default
        @spacing = spacing
        @value = Array(value).compact.join(",")
        @name = name
        super(**attributes)
      end

      def element_attributes(**defaults)
        super(**{
          "data-variant" => variant,
          "data-size" => size,
          "data-spacing" => spacing,
          style: [ attributes[:style], "--gap: #{spacing}" ].compact.join(";"),
          "data-controller" => "shadcn--toggle-group",
          "data-shadcn--toggle-group-type-value" => type,
          "data-shadcn--toggle-group-value-value" => value
        }.merge(defaults))
      end

      def call
        render_element(body: safe_join([ items, content, hidden_input ].flatten.compact))
      end

      private

      def hidden_input
        return unless name

        tag.input(
          type: "hidden",
          name: name,
          value: value,
          "data-shadcn--toggle-group-target": "input"
        )
      end
    end
  end
end
