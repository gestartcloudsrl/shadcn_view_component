# frozen_string_literal: true

module Shadcn
  module Tooltip
    module Content
      # TooltipContent — includes the rotated square Radix renders as the arrow.
      class Component < ApplicationViewComponent
        ARROW_CLASSES = "z-50 size-2.5 translate-y-[calc(-50%_-_2px)] rotate-45 " \
                        "rounded-[2px] bg-foreground fill-foreground"

        slot_name :"tooltip-content"

        style do
          base {
            "z-50 w-fit origin-(--radix-tooltip-content-transform-origin) animate-in " \
            "rounded-md bg-foreground px-3 py-1.5 text-xs text-balance text-background " \
            "fade-in-0 zoom-in-95 data-[side=bottom]:slide-in-from-top-2 " \
            "data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 " \
            "data-[side=top]:slide-in-from-bottom-2 data-[state=closed]:animate-out " \
            "data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95"
          }
        end

        def element_attributes(**defaults)
          super(**{
            role: "tooltip",
            "data-state" => "closed",
            hidden: true,
            "data-shadcn--tooltip-target" => "content"
          }.merge(defaults))
        end

        def call
          render_element(body: safe_join([ content, arrow ]))
        end

        private

        # Two elements, as Radix renders them: a wrapper that Popper pins to the
        # side the content landed on, and inside it the rotated square shadcn
        # styles. They cannot be one element — the classes set `rotate` and
        # `translate`, which in Tailwind v4 are their own CSS properties and
        # compose with `transform` rather than being overridden by it, so a
        # placement written on the same element fights them instead of moving
        # them. `popper.js` positions the wrapper.
        #
        # `display:block` on both, in a style attribute rather than a class,
        # because upstream's arrow is an `<svg>` — a replaced element, which
        # takes a width and a height where an inline `<span>` does not. Without
        # it `size-2.5` applies to nothing and the arrow is 10px of intent and
        # 0px of box: which is how this shipped, invisible however it was
        # placed. A class would have to be one no vendored source carries, and
        # `reverse_parity_spec` is there to notice that.
        def arrow
          tag.span("data-slot": "tooltip-arrow", style: "position:absolute;display:block") do
            tag.span(class: ARROW_CLASSES, style: "display:block")
          end
        end
      end
    end
  end
end
