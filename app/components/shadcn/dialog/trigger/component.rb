# frozen_string_literal: true

module Shadcn
  module Dialog
    module Trigger
      # DialogTrigger
      class Component < ApplicationViewComponent
        default_tag :button
        slot_name :"dialog-trigger"

        def element_attributes(**defaults)
          super(**{
            type: "button",
            "aria-haspopup" => "dialog",
            "aria-expanded" => "false",
            "data-state" => "closed",
            "data-shadcn--dialog-target" => "trigger",
            "data-action" => "shadcn--dialog#open"
          }.merge(defaults))
        end
      end
    end
  end
end
