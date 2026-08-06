# frozen_string_literal: true

module Shadcn
  module Accordion
    module Content
      # AccordionContent — the animated wrapper carries the classes, the inner
      # div takes the padding, exactly as in the TSX.
      class Component < ApplicationViewComponent
        WRAPPER_CLASSES = "overflow-hidden text-sm data-[state=closed]:animate-accordion-up " \
                          "data-[state=open]:animate-accordion-down"

        slot_name :"accordion-content"

        style do
          base { "pt-0 pb-4" }
        end

        def element_attributes(**defaults)
          # The outer element gets no caller classes: shadcn puts them on the
          # inner div instead.
          {
            "data-slot" => "accordion-content",
            "data-state" => "closed",
            "data-orientation" => "vertical",
            role: "region",
            hidden: true,
            class: WRAPPER_CLASSES
          }.merge(defaults).compact
        end

        def call
          content_tag(:div, inner, element_attributes)
        end

        private

        def inner
          inner_attributes = attributes.except(:class)
          content_tag(:div, content, inner_attributes.merge(class: css_classes(attributes[:class])))
        end
      end
    end
  end
end
