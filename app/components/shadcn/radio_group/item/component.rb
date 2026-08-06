# frozen_string_literal: true

module Shadcn
  module RadioGroup
    module Item
      # RadioGroupItem
      class Component < ApplicationViewComponent
        INDICATOR_CLASSES = "relative flex items-center justify-center"
        DOT_CLASSES = "absolute top-1/2 left-1/2 size-2 -translate-x-1/2 -translate-y-1/2 " \
                      "fill-primary"

        default_tag :button
        slot_name :"radio-group-item"

        style do
          base {
            "aspect-square size-4 shrink-0 rounded-full border border-input text-primary " \
            "shadow-xs transition-[color,box-shadow] outline-none focus-visible:border-ring " \
            "focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:cursor-not-allowed " \
            "disabled:opacity-50 aria-invalid:border-destructive " \
            "aria-invalid:ring-destructive/20 dark:bg-input/30 " \
            "dark:aria-invalid:ring-destructive/40"
          }
        end

        attr_reader :value, :checked, :disabled

        def initialize(value:, checked: false, disabled: false, **attributes)
          @value = value.to_s
          @checked = checked
          @disabled = disabled
          super(**attributes)
        end

        def state
          checked ? "checked" : "unchecked"
        end

        def element_attributes(**defaults)
          super(**{
            type: "button",
            role: "radio",
            value: value,
            disabled: (true if disabled),
            tabindex: (checked ? "0" : "-1"),
            "aria-checked" => checked.to_s,
            "data-state" => state,
            "data-value" => value,
            "data-disabled" => (true if disabled),
            "data-shadcn--radio-group-target" => "item",
            "data-action" => "click->shadcn--radio-group#select " \
                             "keydown->shadcn--radio-group#keydown"
          }.merge(defaults))
        end

        def call
          render_element(body: indicator)
        end

        private

        def indicator
          tag.span(
            render(Icon::Component.new("circle", class: DOT_CLASSES)),
            "data-slot": "radio-group-indicator",
            "data-state": state,
            hidden: (true unless checked),
            class: INDICATOR_CLASSES
          )
        end
      end
    end
  end
end
