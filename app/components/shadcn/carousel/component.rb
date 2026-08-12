# frozen_string_literal: true

module Shadcn
  module Carousel
    # Port of registry/new-york-v4/ui/carousel.tsx
    #
    # Upstream builds this on **embla-carousel**, and this port does not. That
    # is a measurement rather than a preference: of embla's 3,170 lines,
    # `carousel.tsx` reaches for six things — `scrollPrev`, `scrollNext`,
    # `canScrollPrev`, `canScrollNext` and the `select`/`reInit` events — and
    # everything else about the component is flex markup and two buttons.
    #
    # The six are what a scroll container already answers. The viewport is a
    # scroller with snap points, so the browser does the dragging, the momentum
    # and the snapping, and this controller reads `scrollLeft` for the two
    # `canScroll` questions and writes it for the two `scroll` ones. It is the
    # same trade `scroll-area` made — the layout is CSS, and the controller
    # computes a number per axis.
    #
    # What is *not* reproduced is in features/carousel.md: `opts` (embla's
    # `loop`, `align`, `slidesToScroll`), the `api` object, its event stream,
    # and plugins. None has markup, so `parity_spec` cannot see their absence;
    # the feature doc is where that is written down.
    class Component < ApplicationViewComponent
      renders_one :carousel_content, "Shadcn::Carousel::Content::Component"
      renders_one :previous, "Shadcn::Carousel::Previous::Component"
      renders_one :next_control, "Shadcn::Carousel::Next::Component"

      slot_name :carousel

      style do
        base { "relative" }
      end

      attr_reader :orientation

      def initialize(orientation: :horizontal, **attributes)
        @orientation = orientation&.to_sym == :vertical ? :vertical : :horizontal
        super(**attributes)
      end

      def element_attributes(**defaults)
        super(**{
          role: "region",
          "aria-roledescription" => "carousel",
          "data-orientation" => orientation,
          "data-controller" => "shadcn--carousel",
          "data-shadcn--carousel-orientation-value" => orientation,
          # Capture, as upstream does (`onKeyDownCapture`, carousel.tsx:119): a
          # slide can hold controls of its own, and one that stops a keydown
          # would otherwise take the carousel's arrows with it.
          "data-action" => "keydown->shadcn--carousel#keydown:capture"
        }.merge(defaults))
      end

      def call
        render_element(body: safe_join([ carousel_content, previous, next_control, content ].compact))
      end
    end
  end
end
