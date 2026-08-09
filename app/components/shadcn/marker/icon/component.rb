# frozen_string_literal: true

module Shadcn
  module Marker
    module Icon
      # MarkerIcon. Its own file rather than a `part` declaration for one
      # reason: upstream stamps `aria-hidden` on it (marker.tsx:46), and `part`
      # declares a slot, classes and a tag and deliberately no other attribute.
      class Component < ApplicationViewComponent
        default_tag :span
        slot_name :"marker-icon"

        style do
          base { "size-4 shrink-0 [&_svg:not([class*='size-'])]:size-4" }
        end

        def element_attributes(**defaults)
          super(**{ "aria-hidden" => "true" }.merge(defaults))
        end
      end
    end
  end
end
