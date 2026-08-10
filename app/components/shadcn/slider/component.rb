# frozen_string_literal: true

module Shadcn
  module Slider
    # Port of registry/new-york-v4/ui/slider.tsx, whose behaviour is Radix's
    # `Slider` — 1,044 lines against shadcn's 63, vendored at
    # `vendor/radix/ui/slider.tsx`.
    #
    # Composes the whole thing, as shadcn's own does: a track holding the filled
    # range, and one thumb per value. Every position is computed here as well as
    # in the controller, so the slider is in the right place before any
    # JavaScript runs — the server knows the values, and a slider that starts at
    # zero and jumps is worse than one that never moves.
    class Component < ApplicationViewComponent
      slot_name :slider

      style do
        base {
          "relative flex w-full touch-none items-center select-none " \
          "data-[disabled]:opacity-50 data-[orientation=vertical]:h-full " \
          "data-[orientation=vertical]:min-h-44 data-[orientation=vertical]:w-auto " \
          "data-[orientation=vertical]:flex-col"
        }
      end

      attr_reader :values, :min, :max, :step, :orientation, :disabled,
                  :min_steps_between_thumbs, :name, :aria_label

      # `value:` takes a number or a list. Upstream's default when neither
      # `value` nor `defaultValue` is given is `[min, max]` — two thumbs, which
      # is surprising until you notice it is what makes the component's own
      # example a range (slider.tsx:17-24).
      def initialize(value: nil, min: 0, max: 100, step: 1, orientation: :horizontal,
                     disabled: false, min_steps_between_thumbs: 0, name: nil,
                     aria_label: nil, **attributes)
        @min = min
        @max = max
        @step = step
        @orientation = orientation&.to_sym || :horizontal
        @disabled = disabled
        @min_steps_between_thumbs = min_steps_between_thumbs
        @name = name
        @aria_label = aria_label
        @values = Array(value.nil? ? [ min, max ] : value)
        super(**attributes)
      end

      def element_attributes(**defaults)
        super(**{
          "data-orientation" => orientation,
          "data-disabled" => (disabled.presence && ""),
          "aria-disabled" => (disabled.presence && "true"),
          "data-controller" => "shadcn--slider",
          "data-shadcn--slider-min-value" => min,
          "data-shadcn--slider-max-value" => max,
          "data-shadcn--slider-step-value" => step,
          "data-shadcn--slider-orientation-value" => orientation,
          "data-shadcn--slider-disabled-value" => disabled,
          "data-shadcn--slider-min-steps-value" => min_steps_between_thumbs,
          "data-action" => "pointerdown->shadcn--slider#trackDown",
          # The transform every thumb's wrapper reads. Radix publishes it on the
          # root so one declaration serves every thumb and the axis is decided
          # in one place.
          style: merged_style(
            "--radix-slider-thumb-transform: #{orientation == :vertical ? 'translateY(50%)' : 'translateX(-50%)'};"
          )
        }.compact.merge(defaults))
      end

      def call
        render_element(body: safe_join([ track, *thumbs, *inputs ]))
      end

      private

      def percent_of(value)
        return 0 if max == min

        ((value.to_f - min) / (max - min) * 100).clamp(0, 100)
      end

      # A single-thumb slider fills from the start of the scale, not from its own
      # value — otherwise the fill has zero width and there is nothing to see.
      # Radix's rule: `valuesCount > 1 ? Math.min(...percentages) : 0`
      # (slider.tsx:592).
      def range_start
        values.size > 1 ? percent_of(values.min) : 0
      end

      def track
        render(Shadcn::Slider::Track::Component.new(orientation:)) do
          render(Shadcn::Slider::Range::Component.new(
            orientation:,
            start_percent: range_start,
            end_percent: percent_of(values.max)
          ))
        end
      end

      # A bare wrapper carries the position so the thumb itself can keep a
      # transition on colour alone. `calc(P% - 8px)` is the flat half of Radix's
      # `getThumbInBoundsOffset` (slider.tsx:908): the exact version slides the
      # correction from +half to −half across the track so the thumb stays
      # inside at both ends, and the controller applies that once it knows the
      # thumb's measured width.
      def thumbs
        values.each_with_index.map do |value, index|
          tag.span(
            render(Shadcn::Slider::Thumb::Component.new(
              orientation:, value:, min:, max:, disabled:, index:,
              "aria-label": label_for(index)
            )),
            style: "transform: var(--radix-slider-thumb-transform); position: absolute; " \
                   "#{orientation == :vertical ? 'bottom' : 'left'}: calc(#{percent_of(value)}% - 8px);",
            "data-shadcn--slider-target": "wrapper"
          )
        end
      end

      # A thumb is a `role="slider"`, and a role does not take its name from the
      # markup around it — the same trap Select, Checkbox and Switch fall into
      # here, and axe fails the page without one. `aria_label:` takes a string
      # or one per thumb, because a two-handled range is two controls and
      # "Price" twice is not a name for either of them.
      def label_for(index)
        return nil if aria_label.blank?

        aria_label.is_a?(Array) ? aria_label[index] : aria_label
      end

      # What a Rails form actually submits. Radix renders these too — shadcn's
      # file does not, because in React the value is state rather than markup.
      def inputs
        return [] if name.blank?

        values.map do |value|
          tag.input(
            type: "hidden", name: values.size > 1 ? "#{name}[]" : name, value:,
            "data-shadcn--slider-target": "input"
          )
        end
      end
    end
  end
end
