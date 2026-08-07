# frozen_string_literal: true

module Shadcn
  module Item
    module Media
      # ItemMedia. Its base classes reach into the named group `Item` opens
      # (`group-has-[[data-slot=item-description]]/item:…`) to shift the media
      # down when the item has a description. That only works while `Item`
      # still carries `group/item`.
      class Component < ApplicationViewComponent
        slot_name :"item-media"

        style do
          base {
            "flex shrink-0 items-center justify-center gap-2 " \
            "group-has-[[data-slot=item-description]]/item:translate-y-0.5 " \
            "group-has-[[data-slot=item-description]]/item:self-start " \
            "[&_svg]:pointer-events-none"
          }

          variants {
            variant {
              default { "bg-transparent" }
              icon {
                "size-8 rounded-sm border bg-muted [&_svg:not([class*='size-'])]:size-4"
              }
              image {
                "size-10 overflow-hidden rounded-sm [&_img]:size-full [&_img]:object-cover"
              }
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
end
