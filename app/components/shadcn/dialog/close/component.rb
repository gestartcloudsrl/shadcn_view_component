# frozen_string_literal: true

module Shadcn
  module Dialog
    module Close
      # DialogClose
      class Component < ApplicationViewComponent
        default_tag :button
        slot_name :"dialog-close"

        def element_attributes(**defaults)
          super(**{
            type: "button",
            "data-action" => "shadcn--dialog#close"
          }.merge(defaults))
        end
      end
    end
  end
end
