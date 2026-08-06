# frozen_string_literal: true

module Shadcn
  module Tooltip
    # Port of registry/new-york-v4/ui/tooltip.tsx
    class Component < ApplicationViewComponent
      renders_one :trigger, "Shadcn::Tooltip::Trigger::Component"
      renders_one :tooltip_content, "Shadcn::Tooltip::Content::Component"

      slot_name :tooltip

      attr_reader :side, :align, :side_offset, :delay_duration

      def initialize(side: :top, align: :center, side_offset: 0, delay_duration: 0, **attributes)
        @side = side&.to_sym || :top
        @align = align&.to_sym || :center
        @side_offset = side_offset
        @delay_duration = delay_duration
        super(**attributes)
      end

      def element_attributes(**defaults)
        super(**{
          style: merged_style(CONTENTS_STYLE),
          "data-controller" => "shadcn--tooltip",
          "data-shadcn--tooltip-side-value" => side,
          "data-shadcn--tooltip-align-value" => align,
          "data-shadcn--tooltip-side-offset-value" => side_offset,
          "data-shadcn--tooltip-delay-value" => delay_duration
        }.merge(defaults))
      end

      def call
        render_element(body: safe_join([ trigger, tooltip_content, content ].compact))
      end
    end
  end
end
