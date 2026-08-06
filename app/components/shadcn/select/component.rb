# frozen_string_literal: true

module Shadcn
  module Select
    # Port of registry/new-york-v4/ui/select.tsx
    #
    # A `role="combobox"` trigger driving a `role="listbox"` layer. When `name:`
    # is given a hidden input mirrors the selection, the way Radix's BubbleSelect
    # does, so the control submits with the form.
    class Component < ApplicationViewComponent
      renders_one :trigger, "Shadcn::Select::Trigger::Component"
      renders_one :select_content, "Shadcn::Select::Content::Component"

      slot_name :select

      attr_reader :open, :value, :name, :placeholder, :side, :align, :side_offset

      def initialize(value: nil, name: nil, placeholder: nil, open: false,
                     side: :bottom, align: :center, side_offset: 4, **attributes)
        @value = value.to_s
        @name = name
        @placeholder = placeholder.to_s
        @open = open
        @side = side&.to_sym || :bottom
        @align = align&.to_sym || :center
        @side_offset = side_offset
        super(**attributes)
      end

      def element_attributes(**defaults)
        super(**{
          style: merged_style(CONTENTS_STYLE),
          "data-controller" => "shadcn--select",
          "data-shadcn--select-open-value" => open,
          "data-shadcn--select-value-value" => value,
          "data-shadcn--select-placeholder-value" => placeholder,
          "data-shadcn--select-side-value" => side,
          "data-shadcn--select-align-value" => align,
          "data-shadcn--select-side-offset-value" => side_offset
        }.merge(defaults))
      end

      def call
        render_element(body: safe_join([ trigger, select_content, content, hidden_input ].compact))
      end

      private

      def hidden_input
        return unless name

        tag.input(
          type: "hidden",
          name: name,
          value: value,
          "data-shadcn--select-target": "input"
        )
      end
    end
  end
end
