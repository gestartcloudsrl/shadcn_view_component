# frozen_string_literal: true

module Shadcn
  module Checkbox
    # Port of registry/new-york-v4/ui/checkbox.tsx
    #
    # Like Radix, this renders a `role="checkbox"` button and — when `name:` is
    # given — a visually hidden native checkbox next to it so the control takes
    # part in normal form submission.
    class Component < ApplicationViewComponent
      INDICATOR_CLASSES = "grid place-content-center text-current transition-none"

      # Radix's BubbleInput styling: present for the form, invisible to the user.
      HIDDEN_INPUT_STYLE = "transform:translateX(-100%);position:absolute;" \
                           "pointer-events:none;opacity:0;margin:0"

      default_tag :button
      slot_name :checkbox

      style do
        base {
          "peer size-4 shrink-0 rounded-[4px] border border-input shadow-xs " \
          "transition-shadow outline-none focus-visible:border-ring focus-visible:ring-[3px] " \
          "focus-visible:ring-ring/50 disabled:cursor-not-allowed disabled:opacity-50 " \
          "aria-invalid:border-destructive aria-invalid:ring-destructive/20 " \
          "data-[state=checked]:border-primary data-[state=checked]:bg-primary " \
          "data-[state=checked]:text-primary-foreground dark:bg-input/30 " \
          "dark:aria-invalid:ring-destructive/40 dark:data-[state=checked]:bg-primary"
        }
      end

      attr_reader :name, :value, :checked, :indeterminate, :disabled

      def initialize(name: nil, value: "on", checked: false, indeterminate: false,
                     disabled: false, **attributes)
        @name = name
        @value = value
        @checked = checked
        @indeterminate = indeterminate
        @disabled = disabled
        super(**attributes)
      end

      def state
        return "indeterminate" if indeterminate

        checked ? "checked" : "unchecked"
      end

      def input_id
        @input_id ||= "shadcn-checkbox-#{SecureRandom.hex(4)}" if name
      end

      def element_attributes(**defaults)
        super(**{
          type: "button",
          role: "checkbox",
          value: value,
          disabled: (true if disabled),
          "aria-checked" => (state == "indeterminate" ? "mixed" : checked.to_s),
          "data-state" => state,
          "data-disabled" => (true if disabled),
          "data-controller" => "shadcn--checkbox",
          "data-shadcn--checkbox-checked-value" => checked,
          "data-shadcn--checkbox-indeterminate-value" => indeterminate,
          "data-shadcn--checkbox-disabled-value" => disabled,
          "data-shadcn--checkbox-input-id-value" => input_id,
          "data-action" => "click->shadcn--checkbox#toggle keydown->shadcn--checkbox#keydown"
        }.merge(defaults))
      end

      def call
        safe_join([ render_element(body: indicator), hidden_input ].compact)
      end

      private

      # Radix mounts the indicator only while checked. It is rendered here
      # regardless — hidden when unchecked, so the markup is correct before
      # JavaScript runs — and the controller detaches it on connect.
      def indicator
        tag.span(
          render(Icon::Component.new("check", class: "size-3.5")),
          "data-slot": "checkbox-indicator",
          "data-state": state,
          "data-shadcn--checkbox-target": "indicator",
          hidden: (true if state == "unchecked"),
          class: INDICATOR_CLASSES
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
