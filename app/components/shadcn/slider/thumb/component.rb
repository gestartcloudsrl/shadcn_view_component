# frozen_string_literal: true

module Shadcn
  module Slider
    module Thumb
      # The handle, and the only focusable thing in the component: `role="slider"`
      # with its own `aria-valuenow`, so a two-thumb range is two controls rather
      # than one with two numbers.
      #
      # Positioning lives on a wrapper the root renders, not here — Radix does
      # the same, and it is what lets the thumb keep `transition-[color,box-shadow]`
      # without the position transitioning too.
      class Component < ApplicationViewComponent
        default_tag :span
        slot_name :"slider-thumb"

        style do
          base {
            "block size-4 shrink-0 rounded-full border border-primary bg-white " \
            "shadow-sm ring-ring/50 transition-[color,box-shadow] hover:ring-4 " \
            "focus-visible:ring-4 focus-visible:outline-hidden " \
            "disabled:pointer-events-none disabled:opacity-50"
          }
        end

        attr_reader :orientation, :value, :min, :max, :disabled, :index

        def initialize(orientation: :horizontal, value: 0, min: 0, max: 100,
                       disabled: false, index: 0, **attributes)
          @orientation = orientation
          @value = value
          @min = min
          @max = max
          @disabled = disabled
          @index = index
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{
            role: "slider",
            tabindex: disabled ? -1 : 0,
            "aria-valuemin" => min,
            "aria-valuemax" => max,
            "aria-valuenow" => value,
            "aria-orientation" => orientation,
            "aria-disabled" => (disabled.presence && "true"),
            "data-orientation" => orientation,
            "data-index" => index,
            "data-shadcn--slider-target" => "thumb",
            "data-action" => "keydown->shadcn--slider#keydown " \
                             "pointerdown->shadcn--slider#thumbDown"
          }.compact.merge(defaults))
        end
      end
    end
  end
end
