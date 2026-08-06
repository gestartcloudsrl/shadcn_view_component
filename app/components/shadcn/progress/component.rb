# frozen_string_literal: true

module Shadcn
  module Progress
    # Port of registry/new-york-v4/ui/progress.tsx
    #
    # Reproduces the ARIA surface and the `data-state` / `data-value` / `data-max`
    # attributes Radix puts on both the root and the indicator.
    class Component < ApplicationViewComponent
      slot_name :progress

      style do
        base { "relative h-2 w-full overflow-hidden rounded-full bg-primary/20" }
      end

      INDICATOR_CLASSES = "h-full w-full flex-1 bg-primary transition-all"

      attr_reader :value, :max

      def initialize(value: nil, max: 100, **attributes)
        @value = value
        @max = max
        super(**attributes)
      end

      def state
        return "indeterminate" if value.nil?

        value >= max ? "complete" : "loading"
      end

      def element_attributes(**defaults)
        super(**{
          role: "progressbar",
          "aria-valuemax" => max,
          "aria-valuemin" => 0,
          "aria-valuenow" => value,
          "data-state" => state,
          "data-value" => value,
          "data-max" => max
        }.merge(defaults))
      end

      def call
        render_element(body: indicator)
      end

      private

      def indicator
        tag.div(
          "data-slot": "progress-indicator",
          "data-state": state,
          "data-value": value,
          "data-max": max,
          class: INDICATOR_CLASSES,
          style: "transform: translateX(-#{100 - (value || 0)}%)"
        )
      end
    end
  end
end
