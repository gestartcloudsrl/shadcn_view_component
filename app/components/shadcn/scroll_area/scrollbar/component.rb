# frozen_string_literal: true

module Shadcn
  module ScrollArea
    module Scrollbar
      # Radix's `ScrollAreaScrollbar`, and shadcn's `ScrollBar`.
      #
      # `data-state` is `hidden` from the server and the controller moves it.
      # Radix *unmounts* the bar instead — with `type="hover"`, the default, it
      # is not in the DOM until the pointer arrives (measured on the live demo).
      # Nothing is unmounted here for the same reason nothing is portalled, so
      # the state attribute carries what a missing element carried there.
      class Component < ApplicationViewComponent
        slot_name :"scroll-area-scrollbar"

        style do
          base { "flex touch-none p-px transition-colors select-none" }

          variants {
            orientation {
              vertical { "h-full w-2.5 border-l border-l-transparent" }
              horizontal { "h-2.5 flex-col border-t border-t-transparent" }
            }
          }

          defaults { { orientation: :vertical } }
        end

        attr_reader :orientation

        def initialize(orientation: :vertical, **attributes)
          @orientation = orientation&.to_sym || :vertical
          super(**attributes)
        end

        def style_variants
          { orientation: }
        end

        # The inline geometry is Radix's: the bar is absolutely positioned
        # against the root and stops short of the corner, and the thumb's size
        # travels as a custom property rather than as a width the controller
        # writes on the thumb itself (measured on the live demo).
        def element_attributes(**defaults)
          super(**{
            style: merged_style(position_style),
            "data-orientation" => orientation,
            "data-state" => "hidden",
            "data-shadcn--scroll-area-target" => "scrollbar",
            "data-action" => "pointerdown->shadcn--scroll-area#startDrag"
          }.merge(defaults))
        end

        def call
          render_element(body: content.presence || render(Shadcn::ScrollArea::Thumb::Component.new))
        end

        private

        def position_style
          if orientation == :vertical
            "position: absolute; top: 0; right: 0; " \
            "bottom: var(--radix-scroll-area-corner-height, 0px);"
          else
            "position: absolute; bottom: 0; left: 0; " \
            "right: var(--radix-scroll-area-corner-width, 0px);"
          end
        end
      end
    end
  end
end
