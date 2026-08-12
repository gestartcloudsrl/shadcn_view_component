# frozen_string_literal: true

module Shadcn
  module Carousel
    module Item
      # CarouselItem — one slide, full width until the caller says otherwise
      # with a `basis-*` of its own, which is upstream's "Sizes" example.
      class Component < ApplicationViewComponent
        slot_name :"carousel-item"

        style do
          base { "min-w-0 shrink-0 grow-0 basis-full" }

          variants {
            orientation {
              horizontal { "pl-4" }
              vertical { "pt-4" }
            }
          }

          defaults { { orientation: :horizontal } }
        end

        attr_reader :orientation

        def initialize(orientation: :horizontal, **attributes)
          @orientation = orientation&.to_sym == :vertical ? :vertical : :horizontal
          super(**attributes)
        end

        def style_variants = { orientation: }

        def element_attributes(**defaults)
          super(**{
            role: "group",
            "aria-roledescription" => "slide"
          }.merge(defaults))
        end
      end
    end
  end
end
