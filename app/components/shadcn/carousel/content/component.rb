# frozen_string_literal: true

module Shadcn
  module Carousel
    module Content
      # CarouselContent — the viewport, with the flex track inside it.
      #
      # The viewport keeps upstream's `overflow-hidden` and nothing else, which
      # matters: `overflow: hidden` still makes an element a scroll container,
      # so `scrollLeft` works on it even though a person cannot drag it. What
      # turns dragging back on is a rule in `shadcn.css` keyed on this
      # `data-slot`, beside the one that hides the scroll area's scrollbars —
      # the same shape of answer, in the same place.
      class Component < ApplicationViewComponent
        renders_many :items, "Shadcn::Carousel::Item::Component"

        slot_name :"carousel-content"

        style do
          base { "overflow-hidden" }
        end

        attr_reader :orientation

        def initialize(orientation: :horizontal, **attributes)
          @orientation = orientation&.to_sym == :vertical ? :vertical : :horizontal
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{
            # Upstream sets no tabindex, and upstream's viewport is not a
            # scroller: embla translates a track inside a hidden overflow, so
            # there is no region for a keyboard to be shut out of. Ours is a
            # scroller, which is the whole mechanism, and axe fails a scrollable
            # region with no keyboard access — the same divergence, for the same
            # reason, as `scroll-area-viewport`.
            #
            # It earns its place beyond the audit: Tab reaches the slides and
            # the arrows move them, where before the only way through was the
            # two buttons.
            tabindex: "0",
            role: "group",
            "aria-roledescription" => "slides",
            "data-orientation" => orientation,
            "data-shadcn--carousel-target" => "viewport"
          }.merge(defaults))
        end

        # The track is upstream's inner div: it takes the caller's classes,
        # where the viewport takes none.
        def call
          render_element(body: tag.div(safe_join([ items, content ].flatten.compact), class: track_classes))
        end

        private

        def track_classes
          horizontal? ? "flex -ml-4" : "flex -mt-4 flex-col"
        end

        def horizontal? = orientation == :horizontal
      end
    end
  end
end
