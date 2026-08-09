# frozen_string_literal: true

module Shadcn
  module Attachment
    module Media
      # AttachmentMedia — the square thumbnail: an icon, or the file itself.
      class Component < ApplicationViewComponent
        slot_name :"attachment-media"

        style do
          base {
            "relative flex aspect-square w-10 shrink-0 items-center justify-center " \
            "overflow-hidden rounded-lg bg-muted text-foreground " \
            "group-data-[orientation=vertical]/attachment:w-full " \
            "group-data-[size=sm]/attachment:w-8 group-data-[size=xs]/attachment:w-7 " \
            "group-data-[size=xs]/attachment:rounded-md " \
            "group-data-[state=error]/attachment:bg-destructive/10 " \
            "group-data-[state=error]/attachment:text-destructive " \
            "group-data-[orientation=vertical]/attachment:*:data-[slot=spinner]:size-6! " \
            "[&_svg]:pointer-events-none [&_svg:not([class*='size-'])]:size-4 " \
            "group-data-[orientation=vertical]/attachment:[&_svg:not([class*='size-'])]:size-6 " \
            "group-data-[size=xs]/attachment:[&_svg:not([class*='size-'])]:size-3.5"
          }

          variants {
            variant {
              icon { "" }
              image {
                "opacity-60 group-data-[state=done]/attachment:opacity-100 " \
                "group-data-[state=idle]/attachment:opacity-100 " \
                "*:[img]:aspect-square *:[img]:w-full *:[img]:object-cover"
              }
            }
          }

          defaults { { variant: :icon } }
        end

        attr_reader :variant

        def initialize(variant: :icon, **attributes)
          @variant = variant&.to_sym || :icon
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
