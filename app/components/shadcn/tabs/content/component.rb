# frozen_string_literal: true

module Shadcn
  module Tabs
    module Content
      # TabsContent
      class Component < ApplicationViewComponent
        slot_name :"tabs-content"

        style do
          base { "flex-1 outline-none" }
        end

        attr_reader :value

        def initialize(value:, **attributes)
          @value = value.to_s
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{
            role: "tabpanel",
            tabindex: "0",
            hidden: true,
            "data-state" => "inactive",
            "data-value" => value,
            "data-shadcn--tabs-target" => "content"
          }.merge(defaults))
        end
      end
    end
  end
end
