# frozen_string_literal: true

module Shadcn
  module MessageScroller
    module Viewport
      # The scroll container. Three of its classes are shadcn's own CSS rather
      # than Tailwind's — `scroll-fade-b`, `scrollbar-thin`,
      # `scrollbar-gutter-stable` — reproduced at the end of `shadcn.css`;
      # without them these would be inert and `parity_spec`, which compares class
      # text and not generated CSS, would not notice.
      #
      # `data-autoscrolling:scrollbar-none` is the one variant here that reads an
      # attribute the controller writes: the scrollbar is hidden while a
      # programmatic scroll is in flight, so a smooth jump does not flicker one
      # in and out.
      class Component < ApplicationViewComponent
        slot_name :"message-scroller-viewport"

        style do
          base {
            "size-full min-h-0 min-w-0 scroll-fade-b scrollbar-thin " \
            "scrollbar-gutter-stable overflow-y-auto overscroll-contain " \
            "contain-content data-autoscrolling:scrollbar-none"
          }
        end

        # `tabindex: 0` is the primitive's (components.tsx:209) and is not
        # decoration: a scrollable region with no focusable content inside it
        # cannot be scrolled from a keyboard at all unless it is focusable
        # itself. axe fails the page without it, which is how the omission was
        # found.
        def element_attributes(**defaults)
          super(**{
            tabindex: 0,
            "data-shadcn--message-scroller-target" => "viewport"
          }.merge(defaults))
        end
      end
    end
  end
end
