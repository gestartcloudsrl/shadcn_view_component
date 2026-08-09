# frozen_string_literal: true

module Shadcn
  module MessageScroller
    # Port of registry/new-york-v4/ui/message-scroller.tsx, which is a thin
    # wrapper over `@shadcn/react/message-scroller` — vendored at
    # `vendor/shadcn-react/` so the Stimulus port has a source to answer to.
    #
    # Upstream's `MessageScrollerProvider` renders no DOM at all: it is pure
    # context holding the five options below (components.tsx:89-107). There is
    # nothing to reproduce, so the options are Stimulus values and the
    # controller lives on this element — the same answer `useSidebar` got.
    class Component < ApplicationViewComponent
      slot_name :"message-scroller"

      style do
        base {
          "group/message-scroller relative flex size-full min-h-0 flex-col overflow-hidden"
        }
      end

      attr_reader :auto_scroll, :default_scroll_position, :scroll_edge_threshold,
                  :scroll_margin, :scroll_previous_item_peek

      # Defaults are upstream's own (components.tsx:89-96). `scrollEdgeThreshold`,
      # `scrollMargin` and `scrollPreviousItemPeek` are undefined there and fall
      # back inside the primitive; passing nil here leaves the value off the
      # element so the controller's own default applies, rather than baking a
      # number this file cannot check.
      def initialize(auto_scroll: false, default_scroll_position: :end,
                     scroll_edge_threshold: nil, scroll_margin: nil,
                     scroll_previous_item_peek: nil, **attributes)
        @auto_scroll = auto_scroll
        @default_scroll_position = default_scroll_position
        @scroll_edge_threshold = scroll_edge_threshold
        @scroll_margin = scroll_margin
        @scroll_previous_item_peek = scroll_previous_item_peek
        super(**attributes)
      end

      def element_attributes(**defaults)
        super(**values.merge(defaults))
      end

      private

      def values
        {
          "data-controller" => "shadcn--message-scroller",
          "data-shadcn--message-scroller-auto-scroll-value" => auto_scroll,
          "data-shadcn--message-scroller-default-scroll-position-value" => default_scroll_position,
          "data-shadcn--message-scroller-scroll-edge-threshold-value" => scroll_edge_threshold,
          "data-shadcn--message-scroller-scroll-margin-value" => scroll_margin,
          "data-shadcn--message-scroller-scroll-previous-item-peek-value" => scroll_previous_item_peek
        }.compact
      end
    end
  end
end
