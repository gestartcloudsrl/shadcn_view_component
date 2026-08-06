# frozen_string_literal: true

module Shadcn
  module DropdownMenu
    module Trigger
      # DropdownMenuTrigger
      class Component < ApplicationViewComponent
        default_tag :button
        slot_name :"dropdown-menu-trigger"

        def element_attributes(**defaults)
          super(**{
            type: "button",
            "aria-haspopup" => "menu",
            "aria-expanded" => "false",
            "data-state" => "closed",
            "data-shadcn--dropdown-menu-target" => "trigger",
            "data-action" => "click->shadcn--dropdown-menu#toggle " \
                             "keydown->shadcn--dropdown-menu#triggerKeydown"
          }.merge(defaults))
        end
      end
    end
  end
end
