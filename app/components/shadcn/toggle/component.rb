# frozen_string_literal: true

module Shadcn
  module Toggle
    # Port of registry/new-york-v4/ui/toggle.tsx
    class Component < ApplicationViewComponent
      default_tag :button
      slot_name :toggle

      style do
        base {
          "inline-flex items-center justify-center gap-2 rounded-md text-sm font-medium " \
          "whitespace-nowrap transition-[color,box-shadow] outline-none hover:bg-muted " \
          "hover:text-muted-foreground focus-visible:border-ring focus-visible:ring-[3px] " \
          "focus-visible:ring-ring/50 disabled:pointer-events-none disabled:opacity-50 " \
          "aria-invalid:border-destructive aria-invalid:ring-destructive/20 " \
          "data-[state=on]:bg-accent data-[state=on]:text-accent-foreground " \
          "dark:aria-invalid:ring-destructive/40 [&_svg]:pointer-events-none " \
          "[&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4"
        }

        variants {
          variant {
            default { "bg-transparent" }
            outline {
              "border border-input bg-transparent shadow-xs hover:bg-accent " \
              "hover:text-accent-foreground"
            }
          }

          size {
            default { "h-9 min-w-9 px-2" }
            sm { "h-8 min-w-8 px-1.5" }
            lg { "h-10 min-w-10 px-2.5" }
          }
        }

        defaults { { variant: :default, size: :default } }
      end

      # Exposed the way shadcn exports `toggleVariants`, for ToggleGroupItem.
      def self.variant_classes(variant: :default, size: :default, class: nil)
        style_config.compile(
          default_style_name.to_sym,
          variant: variant&.to_sym || :default,
          size: size&.to_sym || :default,
          class: binding.local_variable_get(:class)
        )
      end

      attr_reader :variant, :size, :pressed, :disabled

      def initialize(variant: :default, size: :default, pressed: false, disabled: false,
                     **attributes)
        @variant = variant&.to_sym || :default
        @size = size&.to_sym || :default
        @pressed = pressed
        @disabled = disabled
        super(**attributes)
      end

      def style_variants
        { variant:, size: }
      end

      def element_attributes(**defaults)
        super(**{
          type: "button",
          disabled: (true if disabled),
          "aria-pressed" => pressed.to_s,
          "data-state" => (pressed ? "on" : "off"),
          "data-disabled" => (true if disabled),
          "data-controller" => "shadcn--toggle",
          "data-shadcn--toggle-pressed-value" => pressed,
          "data-shadcn--toggle-disabled-value" => disabled,
          "data-action" => "shadcn--toggle#toggle"
        }.merge(defaults))
      end
    end
  end
end
