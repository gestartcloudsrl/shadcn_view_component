# frozen_string_literal: true

module Shadcn
  module Select
    module Group
      # SelectGroup
      class Component < ApplicationViewComponent
        slot_name :"select-group"

        def element_attributes(**defaults)
          super(**{ role: "group" }.merge(defaults))
        end
      end
    end
  end
end
