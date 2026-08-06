# frozen_string_literal: true

module Shadcn
  module DropdownMenu
    module RadioGroup
      # DropdownMenuRadioGroup
      class Component < ApplicationViewComponent
        slot_name :"dropdown-menu-radio-group"

        def element_attributes(**defaults)
          super(**{ role: "group" }.merge(defaults))
        end
      end
    end
  end
end
