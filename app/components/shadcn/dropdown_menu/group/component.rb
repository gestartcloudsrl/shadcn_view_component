# frozen_string_literal: true

module Shadcn
  module DropdownMenu
    module Group
      # DropdownMenuGroup
      class Component < ApplicationViewComponent
        slot_name :"dropdown-menu-group"

        def element_attributes(**defaults)
          super(**{ role: "group" }.merge(defaults))
        end
      end
    end
  end
end
