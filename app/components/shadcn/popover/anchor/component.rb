# frozen_string_literal: true

module Shadcn
  module Popover
    module Anchor
      # PopoverAnchor — positions the content against something other than the
      # trigger.
      class Component < ApplicationViewComponent
        slot_name :"popover-anchor"

        def element_attributes(**defaults)
          super(**{ "data-shadcn--popover-target" => "anchor" }.merge(defaults))
        end
      end
    end
  end
end
