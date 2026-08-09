# frozen_string_literal: true

module Shadcn
  module MessageScroller
    module Content
      # The column of messages, and the tail spacer under it.
      #
      # The spacer is not decoration and not a slot: it is a hidden sibling of
      # the rows whose height the controller sets, so the last message can be
      # scrolled to the *top* of the viewport rather than stopping at the bottom
      # (components.tsx:301-307). It is also the reason `scroll_geometry.js`
      # measures the rows instead of reading `scrollHeight`, which the spacer
      # inflates.
      #
      # `role="log"` with `aria-relevant="additions"` is upstream's default and
      # is what makes an arriving message announce itself. Both are defaults, so
      # a caller who knows better can say so.
      class Component < ApplicationViewComponent
        slot_name :"message-scroller-content"

        style do
          base { "flex h-max min-h-full flex-col gap-8" }
        end

        def element_attributes(**defaults)
          super(**{
            role: "log",
            "aria-relevant" => "additions",
            "data-shadcn--message-scroller-target" => "content"
          }.merge(defaults))
        end

        def call
          render_element(body: safe_join([ content, spacer ]))
        end

        private

        def spacer
          tag.div(
            "aria-hidden": true,
            "data-message-scroller-spacer": "",
            "data-shadcn--message-scroller-target": "spacer",
            hidden: true
          )
        end
      end
    end
  end
end
