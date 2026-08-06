# frozen_string_literal: true

module Shadcn
  module Accordion
    module Trigger
      # AccordionTrigger — Radix wraps the button in an `<h3>` header, which is
      # where shadcn puts the `flex` class.
      class Component < ApplicationViewComponent
        HEADER_CLASSES = "flex"

        default_tag :button
        slot_name :"accordion-trigger"

        style do
          base {
            "flex flex-1 items-start justify-between gap-4 rounded-md py-4 text-left " \
            "text-sm font-medium transition-all outline-none hover:underline " \
            "focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 " \
            "disabled:pointer-events-none disabled:opacity-50 " \
            "[&[data-state=open]>svg]:rotate-180"
          }
        end

        CHEVRON_CLASSES = "pointer-events-none size-4 shrink-0 translate-y-0.5 " \
                          "text-muted-foreground transition-transform duration-200"

        def element_attributes(**defaults)
          super(**{
            type: "button",
            "data-state" => "closed",
            "data-orientation" => "vertical",
            "aria-expanded" => "false",
            "data-shadcn--accordion-target" => "trigger",
            "data-action" => "click->shadcn--accordion#toggle keydown->shadcn--accordion#keydown"
          }.merge(defaults))
        end

        def call
          tag.h3(class: HEADER_CLASSES, "data-slot": "accordion-header") do
            render_element(body: safe_join([ content, chevron ]))
          end
        end

        private

        def chevron
          render(Icon::Component.new("chevron-down", class: CHEVRON_CLASSES))
        end
      end
    end
  end
end
