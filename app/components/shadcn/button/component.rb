# frozen_string_literal: true

module Shadcn
  module Button
    # Port of registry/new-york-v4/ui/button.tsx
    class Component < ApplicationViewComponent
      default_tag :button
      slot_name :button

      style do
        base {
          "inline-flex shrink-0 items-center justify-center gap-2 rounded-md text-sm font-medium " \
          "whitespace-nowrap transition-all outline-none focus-visible:border-ring " \
          "focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:pointer-events-none " \
          "disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-destructive/20 " \
          "dark:aria-invalid:ring-destructive/40 [&_svg]:pointer-events-none [&_svg]:shrink-0 " \
          "[&_svg:not([class*='size-'])]:size-4"
        }

        variants {
          variant {
            default { "bg-primary text-primary-foreground hover:bg-primary/90" }
            destructive {
              "bg-destructive text-white hover:bg-destructive/90 " \
              "focus-visible:ring-destructive/20 dark:bg-destructive/60 " \
              "dark:focus-visible:ring-destructive/40"
            }
            outline {
              "border bg-background shadow-xs hover:bg-accent hover:text-accent-foreground " \
              "dark:border-input dark:bg-input/30 dark:hover:bg-input/50"
            }
            secondary { "bg-secondary text-secondary-foreground hover:bg-secondary/80" }
            ghost { "hover:bg-accent hover:text-accent-foreground dark:hover:bg-accent/50" }
            link { "text-primary underline-offset-4 hover:underline" }
          }

          size {
            default { "h-9 px-4 py-2 has-[>svg]:px-3" }
            xs {
              "h-6 gap-1 rounded-md px-2 text-xs has-[>svg]:px-1.5 " \
              "[&_svg:not([class*='size-'])]:size-3"
            }
            sm { "h-8 gap-1.5 rounded-md px-3 has-[>svg]:px-2.5" }
            lg { "h-10 rounded-md px-6 has-[>svg]:px-4" }
            icon { "size-9" }
            # `send` is how the DSL takes variant names that are not valid Ruby
            # method names — the keys have to stay identical to the TSX ones.
            send(:"icon-xs") { "size-6 rounded-md [&_svg:not([class*='size-'])]:size-3" }
            send(:"icon-sm") { "size-8" }
            send(:"icon-lg") { "size-10" }
          }
        }

        defaults { { variant: :default, size: :default } }
      end

      # Ruby equivalent of shadcn's exported `buttonVariants` — other components
      # (pagination links, dialog footers, …) borrow the button's classes.
      def self.variant_classes(variant: :default, size: :default, class: nil)
        style_config.compile(
          default_style_name.to_sym,
          variant: variant&.to_sym,
          size: size&.to_sym,
          class: binding.local_variable_get(:class)
        )
      end

      attr_reader :variant, :size

      def initialize(variant: :default, size: :default, **attributes)
        @variant = variant&.to_sym || :default
        @size = size&.to_sym || :default
        super(**attributes)
      end

      def style_variants
        { variant:, size: }
      end

      def element_attributes(**defaults)
        super(**{ "data-variant" => variant, "data-size" => size }.merge(defaults))
      end
    end
  end
end
