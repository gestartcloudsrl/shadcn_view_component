# frozen_string_literal: true

module Shadcn
  module MessageScroller
    module Item
      # One row. Its two attributes are the markup's half of the contract with
      # `scroll_geometry.js`, which reads `dataset.messageId` and
      # `dataset.scrollAnchor` — so they are rendered whether or not a controller
      # is present.
      #
      # `data-scroll-anchor` is written as the string `"false"` rather than
      # omitted, exactly as upstream does (components.tsx:340). Nothing here
      # depends on the difference, but a host's CSS might.
      #
      # `content-visibility: auto` lets the browser skip laying out rows that are
      # off screen, and `contain-intrinsic-size` is the guess it uses for their
      # height until it does. They arrive as arbitrary properties because
      # Tailwind has no utility for either.
      class Component < ApplicationViewComponent
        slot_name :"message-scroller-item"

        style do
          base {
            "min-w-0 shrink-0 [contain-intrinsic-size:auto_10rem] [content-visibility:auto]"
          }
        end

        attr_reader :message_id, :scroll_anchor

        def initialize(message_id: nil, scroll_anchor: false, **attributes)
          @message_id = message_id
          @scroll_anchor = scroll_anchor
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{
            "data-message-id" => message_id,
            "data-scroll-anchor" => scroll_anchor.to_s
          }.compact.merge(defaults))
        end
      end
    end
  end
end
