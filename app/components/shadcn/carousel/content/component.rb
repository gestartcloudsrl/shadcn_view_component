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
          # Held for the track and kept off the viewport, which is upstream's
          # arrangement: `{...props}` and the className land on the inner div.
          @track = attributes
          super()
        end

        # The caller's attributes went to the track above, so the viewport is
        # given only its own.
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

        # Upstream gives the *track* the caller's className and leaves the
        # viewport with `overflow-hidden` and nothing else (carousel.tsx:138-152).
        # This port had it the other way round, so a preview asking for a
        # smaller gutter with `-ml-2` put it on the viewport, where it does
        # nothing, while the track kept `-ml-4` and the items took `pl-2`. A
        # gutter that disagrees with its own padding is a slide whose content
        # starts outside the window, which is a card with no left border.
        def call
          render_element(body: tag.div(safe_join([ items, content ].flatten.compact), **track_attributes))
        end

        private

        def track_attributes
          extra = @track.except(:class, "class")

          # Merged rather than concatenated: a caller asking for a smaller gutter
          # passes `-ml-2`, and `flex -ml-4 -ml-2` leaves both in the attribute
          # for the cascade to arbitrate. `cn` is what resolves that everywhere
          # else in this port.
          extra.merge(class: ShadcnViewComponent.cn(track_classes, @track[:class] || @track["class"]))
        end

        def track_classes
          horizontal? ? "flex -ml-4" : "flex -mt-4 flex-col"
        end

        def horizontal? = orientation == :horizontal
      end
    end
  end
end
