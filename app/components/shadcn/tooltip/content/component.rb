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

        def arrow
          tag.span(class: ARROW_CLASSES, "data-slot": "tooltip-arrow")
        end
      end
    end
  end
end
