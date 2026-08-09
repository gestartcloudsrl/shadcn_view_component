# frozen_string_literal: true

module Shadcn
  module Bubble
    module Reactions
      # BubbleReactions — the pill of emoji that overlaps a bubble's corner.
      # Two independent axes, so two `variants` groups rather than one
      # (bubble.tsx:85-103).
      class Component < ApplicationViewComponent
        slot_name :"bubble-reactions"

        style do
          base {
            "absolute z-10 flex w-fit shrink-0 items-center justify-center gap-1 " \
            "rounded-full bg-muted px-1.5 py-0.5 text-sm ring-3 ring-card has-[button]:p-0"
          }

          variants {
            side {
              top { "top-0 -translate-y-3/4" }
              bottom { "bottom-0 translate-y-3/4" }
            }

            align {
              start { "left-3" }
              # `end` is a Ruby keyword, so it cannot be a block name here.
              # `send` keeps the variant's name exactly upstream's, the way
              # `button` declares `icon-xs`.
              send(:end) { "right-3" }
            }
          }

          defaults { { side: :bottom, align: :end } }
        end

        attr_reader :side, :align

        def initialize(side: :bottom, align: :end, **attributes)
          @side = side&.to_sym || :bottom
          @align = align&.to_sym || :end
          super(**attributes)
        end

        def style_variants
          { side:, align: }
        end

        def element_attributes(**defaults)
          super(**{ "data-align" => align, "data-side" => side }.merge(defaults))
        end
      end
    end
  end
end
