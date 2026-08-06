# frozen_string_literal: true

module Shadcn
  module Popover
    module Trigger
      # PopoverTrigger
      class Component < ApplicationViewComponent
        default_tag :button
        slot_name :"popover-trigger"

        def element_attributes(**defaults)
          super(**{
            type: "button",
            "aria-haspopup" => "dialog",
            "aria-expanded" => "false",
            "data-state" => "closed",
            "data-shadcn--popover-target" => "trigger",
            "data-action" => "shadcn--popover#toggle"
          }.merge(defaults))
        end
      end
    end
  end
end
