# frozen_string_literal: true

module Shadcn
  module Slider
    module Range
      # The filled part of the groove, between the lowest and highest thumb.
      # Two inline percentages rather than a width, which is Radix's own
      # (measured: `left:25%;right:50%` for values 25 and 50) and is what makes
      # a two-thumb range one element instead of two.
      class Component < ApplicationViewComponent
        slot_name :"slider-range"

        style do
          base {
            "absolute bg-primary data-[orientation=horizontal]:h-full " \
            "data-[orientation=vertical]:w-full"
          }
        end

        attr_reader :orientation, :start_percent, :end_percent

        def initialize(orientation: :horizontal, start_percent: 0, end_percent: 100, **attributes)
          @orientation = orientation
          @start_percent = start_percent
          @end_percent = end_percent
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{
            "data-orientation" => orientation,
            "data-shadcn--slider-target" => "range",
            style: merged_style(edges)
          }.merge(defaults))
        end

        private

        # Vertical sliders fill from the bottom, so the pair of edges changes
        # with the axis rather than the numbers doing.
        def edges
          if orientation.to_sym == :vertical
            "bottom: #{start_percent}%; top: #{100 - end_percent}%;"
          else
            "left: #{start_percent}%; right: #{100 - end_percent}%;"
          end
        end
      end
    end
  end
end
