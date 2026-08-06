# frozen_string_literal: true

module Shadcn
  module Accordion
    module Item
      # AccordionItem
      class Component < ApplicationViewComponent
        renders_one :trigger, "Shadcn::Accordion::Trigger::Component"
        renders_one :panel, "Shadcn::Accordion::Content::Component"

        slot_name :"accordion-item"

        style do
          base { "border-b last:border-b-0" }
        end

        attr_reader :value, :disabled

        def initialize(value:, disabled: false, **attributes)
          @value = value.to_s
          @disabled = disabled
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{
            "data-value" => value,
            "data-state" => "closed",
            "data-orientation" => "vertical",
            "data-disabled" => (true if disabled),
            "data-shadcn--accordion-target" => "item"
          }.merge(defaults))
        end

        def call
          render_element(body: safe_join([ trigger, panel, content ].compact))
        end
      end
    end
  end
end
