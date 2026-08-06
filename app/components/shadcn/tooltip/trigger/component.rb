# frozen_string_literal: true

module Shadcn
  module Tooltip
    module Trigger
      # TooltipTrigger — opens on hover and on keyboard focus.
      class Component < ApplicationViewComponent
        default_tag :button
        slot_name :"tooltip-trigger"

        def element_attributes(**defaults)
          super(**{
            type: "button",
            "data-state" => "closed",
            "data-shadcn--tooltip-target" => "trigger",
            "data-action" => "mouseenter->shadcn--tooltip#show " \
                             "mouseleave->shadcn--tooltip#hide " \
                             "focus->shadcn--tooltip#show " \
                             "blur->shadcn--tooltip#hide"
          }.merge(defaults))
        end
      end
    end
  end
end
