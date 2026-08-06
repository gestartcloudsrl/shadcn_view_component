# frozen_string_literal: true

module Shadcn
  module Switch
    # Port of registry/new-york-v4/ui/switch.tsx
    class Component < ApplicationViewComponent
      THUMB_CLASSES = "pointer-events-none block rounded-full bg-background ring-0 " \
                      "transition-transform group-data-[size=default]/switch:size-4 " \
                      "group-data-[size=sm]/switch:size-3 " \
                      "data-[state=checked]:translate-x-[calc(100%-2px)] " \
                      "data-[state=unchecked]:translate-x-0 " \
                      "dark:data-[state=checked]:bg-primary-foreground " \
                      "dark:data-[state=unchecked]:bg-foreground"

      HIDDEN_INPUT_STYLE = "transform:translateX(-100%);position:absolute;" \
                           "pointer-events:none;opacity:0;margin:0"

      default_tag :button
      slot_name :switch

      style do
        base {
          "peer group/switch inline-flex shrink-0 items-center rounded-full " \
          "border border-transparent shadow-xs transition-all outline-none " \
          "focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 " \
          "disabled:cursor-not-allowed disabled:opacity-50 " \
          "data-[size=default]:h-[1.15rem] data-[size=default]:w-8 " \
          "data-[size=sm]:h-3.5 data-[size=sm]:w-6 " \
          "data-[state=checked]:bg-primary data-[state=unchecked]:bg-input " \
          "dark:data-[state=unchecked]:bg-input/80"
        }
      end

      attr_reader :size, :name, :value, :checked, :disabled

      def initialize(size: :default, name: nil, value: "on", checked: false, disabled: false,
                     **attributes)
        @size = size&.to_sym || :default
        @name = name
        @value = value
        @checked = checked
        @disabled = disabled
        super(**attributes)
      end

      def state
        checked ? "checked" : "unchecked"
      end

      def input_id
        @input_id ||= "shadcn-switch-#{SecureRandom.hex(4)}" if name
      end

      def element_attributes(**defaults)
        super(**{
          type: "button",
          role: "switch",
          value: value,
          disabled: (true if disabled),
          "aria-checked" => checked.to_s,
          "data-state" => state,
          "data-size" => size,
          "data-disabled" => (true if disabled),
          "data-controller" => "shadcn--switch",
          "data-shadcn--switch-checked-value" => checked,
          "data-shadcn--switch-disabled-value" => disabled,
          "data-shadcn--switch-input-id-value" => input_id,
          "data-action" => "click->shadcn--switch#toggle keydown->shadcn--switch#keydown"
        }.merge(defaults))
      end

      def call
        safe_join([ render_element(body: thumb), hidden_input ].compact)
      end

      private

      def thumb
        tag.span(
          "data-slot": "switch-thumb",
          "data-state": state,
          "data-shadcn--switch-target": "thumb",
          class: THUMB_CLASSES
        )
      end

      def hidden_input
        return unless name

        tag.input(
          type: "checkbox",
          id: input_id,
          name: name,
          value: value,
          checked: checked,
          disabled: (true if disabled),
          "aria-hidden": "true",
          tabindex: "-1",
          style: HIDDEN_INPUT_STYLE
        )
      end
    end
  end
end
