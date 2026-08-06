# frozen_string_literal: true

module Shadcn
  module Avatar
    module Image
      class Component < ApplicationViewComponent
        default_tag :img
        slot_name :"avatar-image"

        style do
          base { "aspect-square size-full" }
        end

        def element_attributes(**defaults)
          super(**{ "data-shadcn--avatar-target" => "image" }.merge(defaults))
        end
      end
    end
  end
end
