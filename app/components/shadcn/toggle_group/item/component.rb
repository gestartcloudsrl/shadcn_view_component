# frozen_string_literal: true

module Shadcn
  module ToggleGroup
    module Item
      # ToggleGroupItem — styled with the toggle's own variants, like the TSX
      # does via `toggleVariants({ variant, size })`.
      class Component < ApplicationViewComponent
        EXTRA_CLASSES = "w-auto min-w-0 shrink-0 px-3 focus:z-10 focus-visible:z-10 " \
                        "data-[spacing=0]:rounded-none data-[spacing=0]:shadow-none " \
                        "data-[spacing=0]:first:rounded-l-md data-[spacing=0]:last:rounded-r-md " \
                        "data-[spacing=0]:data-[variant=outline]:border-l-0 " \
                        "data-[spacing=0]:data-[variant=outline]:first:border-l"

        default_tag :button
        slot_name :"toggle-group-item"

        attr_reader :value, :variant, :size, :spacing, :pressed, :disabled

        def initialize(value:, variant: :default, size: :default, spacing: 0,
                       pressed: false, disabled: false, **attributes)
          @value = value.to_s
          @variant = variant&.to_sym || :default
          @size = size&.to_sym || :default
          @spacing = spacing
          @pressed = pressed
          @disabled = disabled
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{
            type: "button",
            disabled: (true if disabled),
            tabindex: "-1",
            "aria-pressed" => pressed.to_s,
            "data-state" => (pressed ? "on" : "off"),
            "data-value" => value,
            "data-variant" => variant,
            "data-size" => size,
            "data-spacing" => spacing,
            "data-disabled" => (true if disabled),
            "data-shadcn--toggle-group-target" => "item",
            "data-action" => "click->shadcn--toggle-group#toggle " \
                             "keydown->shadcn--toggle-group#keydown"
          }.merge(defaults))
        end

        def css_classes(extra = nil)
          Toggle::Component.variant_classes(
            variant:,
            size:,
            class: ShadcnViewComponent.cn(EXTRA_CLASSES, extra)
          )
        end
      end
    end
  end
end
