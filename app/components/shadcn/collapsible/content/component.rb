# frozen_string_literal: true

module Shadcn
  module Collapsible
    module Content
      # CollapsibleContent
      class Component < ApplicationViewComponent
        slot_name :"collapsible-content"

        def element_attributes(**defaults)
          super(**{
            "data-state" => "closed",
            hidden: true,
            "data-shadcn--collapsible-target" => "content"
          }.merge(defaults))
        end
      end
    end
  end
end
