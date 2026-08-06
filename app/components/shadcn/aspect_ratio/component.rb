# frozen_string_literal: true

module Shadcn
  module AspectRatio
    # Port of registry/new-york-v4/ui/aspect-ratio.tsx
    #
    # Radix wraps the content in a relatively positioned box whose bottom
    # padding encodes the ratio, then absolutely positions the slot inside it.
    class Component < ApplicationViewComponent
      slot_name :"aspect-ratio"

      attr_reader :ratio

      def initialize(ratio: 1, **attributes)
        @ratio = ratio
        super(**attributes)
      end

      def call
        wrapper_style = "position:relative;width:100%;padding-bottom:#{100.0 / ratio}%"

        content_tag(:div, style: wrapper_style) do
          render_element(body: content, style: inner_style)
        end
      end

      private

      def inner_style
        [ attributes[:style], "position:absolute;top:0;right:0;bottom:0;left:0" ].compact.join(";")
      end
    end
  end
end
