# frozen_string_literal: true

module Shadcn
  module ButtonGroup
    # Port of registry/new-york-v4/ui/button-group.tsx
    class Component < ApplicationViewComponent
      slot_name :"button-group"

      style do
        base {
          "flex w-fit items-stretch has-[>[data-slot=button-group]]:gap-2 " \
          "[&>*]:focus-visible:relative [&>*]:focus-visible:z-10 " \
          "has-[select[aria-hidden=true]:last-child]:[&>[data-slot=select-trigger]:last-of-type]:rounded-r-md " \
          "[&>[data-slot=select-trigger]:not([class*='w-'])]:w-fit [&>input]:flex-1"
        }

        variants {
          orientation {
            horizontal {
              "[&>*:not(:first-child)]:rounded-l-none [&>*:not(:first-child)]:border-l-0 " \
              "[&>*:not(:last-child)]:rounded-r-none"
            }
            vertical {
              "flex-col [&>*:not(:first-child)]:rounded-t-none " \
              "[&>*:not(:first-child)]:border-t-0 [&>*:not(:last-child)]:rounded-b-none"
            }
          }
        }

        defaults { { orientation: :horizontal } }
      end

      attr_reader :orientation

      # Left nil rather than defaulted, because upstream destructures
      # `orientation` with no default: the classes fall back to horizontal via
      # cva's `defaultVariants`, but `data-orientation` is only emitted when the
      # caller actually passed one.
      def initialize(orientation: nil, **attributes)
        @orientation = orientation&.to_sym
        super(**attributes)
      end

      def style_variants
        { orientation: orientation || :horizontal }
      end

      def element_attributes(**defaults)
        super(**{ role: "group", "data-orientation" => orientation }.merge(defaults))
      end
    end
  end
end
