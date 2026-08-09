# frozen_string_literal: true

module Shadcn
  module ScrollArea
    # Port of registry/new-york-v4/ui/scroll-area.tsx, whose behaviour is Radix's
    # `ScrollArea` — 1,189 lines against shadcn's 58, and vendored at
    # `vendor/radix/ui/scroll-area.tsx`.
    #
    # Like shadcn's own, this composes the whole thing rather than exposing the
    # parts: the viewport, one scrollbar per requested axis, and the corner where
    # two of them meet. `orientation:` is this port's way of asking for the
    # second bar, which shadcn does by passing a second `<ScrollBar>` as a child
    # — a shape that relies on React's Slottable to hoist it out of the viewport
    # and has no counterpart here.
    #
    # Two of Radix's four `type` strategies are reproduced: `hover`, its default,
    # and `always`. See features/scroll-area.md.
    class Component < ApplicationViewComponent
      slot_name :"scroll-area"

      style do
        base { "relative" }
      end

      attr_reader :orientation, :type, :scroll_hide_delay

      def initialize(orientation: :vertical, type: :hover, scroll_hide_delay: 600, **attributes)
        @orientation = orientation&.to_sym || :vertical
        @type = type&.to_sym || :hover
        @scroll_hide_delay = scroll_hide_delay
        super(**attributes)
      end

      def element_attributes(**defaults)
        super(**{
          "data-controller" => "shadcn--scroll-area",
          "data-shadcn--scroll-area-type-value" => type,
          "data-shadcn--scroll-area-hide-delay-value" => scroll_hide_delay,
          "data-action" => "pointerenter->shadcn--scroll-area#pointerEnter " \
                           "pointerleave->shadcn--scroll-area#pointerLeave"
        }.merge(defaults))
      end

      def call
        render_element(body: safe_join([ viewport, *scrollbars, corner ].compact))
      end

      private

      def horizontal? = [ :horizontal, :both ].include?(orientation)
      def vertical? = [ :vertical, :both ].include?(orientation)

      def viewport
        render(
          Shadcn::ScrollArea::Viewport::Component.new(horizontal: horizontal?, vertical: vertical?)
        ) { content }
      end

      def scrollbars
        [
          (bar(:vertical) if vertical?),
          (bar(:horizontal) if horizontal?)
        ]
      end

      def bar(axis)
        render(Shadcn::ScrollArea::Scrollbar::Component.new(orientation: axis))
      end

      # Only where two bars meet. Radix sizes it from the two bars' thicknesses
      # and publishes them as the custom properties each bar stops short at.
      def corner
        return unless horizontal? && vertical?

        tag.div(
          style: "position: absolute; right: 0; bottom: 0; " \
                 "width: var(--radix-scroll-area-corner-width, 0px); " \
                 "height: var(--radix-scroll-area-corner-height, 0px);",
          "data-shadcn--scroll-area-target": "corner"
        )
      end
    end
  end
end
