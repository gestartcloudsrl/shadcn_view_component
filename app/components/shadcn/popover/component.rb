# frozen_string_literal: true

module Shadcn
  module Popover
    # Port of registry/new-york-v4/ui/popover.tsx
    class Component < ApplicationViewComponent
      renders_one :trigger, "Shadcn::Popover::Trigger::Component"
      renders_one :anchor, "Shadcn::Popover::Anchor::Component"
      renders_one :popover_content, "Shadcn::Popover::Content::Component"

      slot_name :popover

      attr_reader :open, :side, :align, :side_offset, :align_offset

      def initialize(open: false, side: :bottom, align: :center, side_offset: 4,
                     align_offset: 0, **attributes)
        @open = open
        @side = side&.to_sym || :bottom
        @align = align&.to_sym || :center
        @side_offset = side_offset
        @align_offset = align_offset
        super(**attributes)
      end

      def element_attributes(**defaults)
        super(**{
          style: merged_style(CONTENTS_STYLE),
          "data-controller" => "shadcn--popover",
          "data-shadcn--popover-open-value" => open,
          "data-shadcn--popover-side-value" => side,
          "data-shadcn--popover-align-value" => align,
          "data-shadcn--popover-side-offset-value" => side_offset,
          "data-shadcn--popover-align-offset-value" => align_offset
        }.merge(defaults))
      end

      def call
        render_element(body: safe_join([ anchor, trigger, popover_content, content ].compact))
      end
    end
  end
end
