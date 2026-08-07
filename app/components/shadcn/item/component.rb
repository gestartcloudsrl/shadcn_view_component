# frozen_string_literal: true

module Shadcn
  module Item
    # Port of registry/new-york-v4/ui/item.tsx
    #
    # `group/item` is half a mechanism: `ItemMedia`'s
    # `group-has-[[data-slot=item-description]]/item:…` classes reach back into
    # this named group to shift the media when a description is present. Both
    # halves have to stay exactly as upstream wrote them — parity checks that
    # each class exists, not that they still refer to each other.
    class Component < ApplicationViewComponent
      slot_name :item

      style do
        base {
          "group/item flex flex-wrap items-center rounded-md border border-transparent " \
          "text-sm transition-colors duration-100 outline-none focus-visible:border-ring " \
          "focus-visible:ring-[3px] focus-visible:ring-ring/50 [a]:transition-colors " \
          "[a]:hover:bg-accent/50"
        }

        variants {
          variant {
            default { "bg-transparent" }
            outline { "border-border" }
            muted { "bg-muted/50" }
          }

          size {
            default { "gap-4 p-4" }
            sm { "gap-2.5 px-4 py-3" }
          }
        }

        defaults { { variant: :default, size: :default } }
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
