# frozen_string_literal: true

module Shadcn
  module Collapsible
    module Trigger
      # CollapsibleTrigger
      class Component < ApplicationViewComponent
        default_tag :button
        slot_name :"collapsible-trigger"

        def element_attributes(**defaults)
          super(**{
            type: "button",
            "aria-expanded" => "false",
            "data-state" => "closed",
            "data-shadcn--collapsible-target" => "trigger",
            "data-action" => "shadcn--collapsible#toggle"
          }.merge(defaults))
        end
      end
    end
  end
end
