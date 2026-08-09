# frozen_string_literal: true

module Shadcn
  module Marker
    # Port of registry/new-york-v4/ui/marker.tsx
    class Component < ApplicationViewComponent
      slot_name :marker

      style do
        base {
          "group/marker relative flex min-h-4 w-full items-center gap-2 text-left text-sm " \
          "text-muted-foreground [&_svg:not([class*='size-'])]:size-4 [a]:underline " \
          "[a]:underline-offset-3 [a]:hover:text-foreground"
        }

        variants {
          variant {
            default { "" }
            separator {
              "before:mr-1 before:h-px before:min-w-0 before:flex-1 before:bg-border " \
              "after:ml-1 after:h-px after:min-w-0 after:flex-1 after:bg-border"
            }
            border { "border-b border-border pb-2" }
          }
        }

        defaults { { variant: :default } }
      end

      attr_reader :variant

      def initialize(variant: :default, **attributes)
        @variant = variant&.to_sym || :default
        super(**attributes)
      end

      def style_variants
        { variant: }
      end

      def element_attributes(**defaults)
        super(**{ "data-variant" => variant }.merge(defaults))
      end
    end
  end
end
