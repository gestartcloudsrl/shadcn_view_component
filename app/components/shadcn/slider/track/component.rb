# frozen_string_literal: true

module Shadcn
  module Slider
    module Track
      # The groove. Its own file only for `data-orientation`, which every part
      # of this family carries and which `part` does not do.
      class Component < ApplicationViewComponent
        slot_name :"slider-track"

        style do
          base {
            "relative grow overflow-hidden rounded-full bg-muted " \
            "data-[orientation=horizontal]:h-1.5 data-[orientation=horizontal]:w-full " \
            "data-[orientation=vertical]:h-full data-[orientation=vertical]:w-1.5"
          }
        end

        attr_reader :orientation

        def initialize(orientation: :horizontal, **attributes)
          @orientation = orientation
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{ "data-orientation" => orientation }.merge(defaults))
        end
      end
    end
  end
end
