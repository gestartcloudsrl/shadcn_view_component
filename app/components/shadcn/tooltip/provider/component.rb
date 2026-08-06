# frozen_string_literal: true

module Shadcn
  module Tooltip
    module Provider
      # TooltipProvider — in React this only supplies the shared delay through
      # context. Kept as a component so call sites read like the TSX; it renders
      # nothing but its children.
      class Component < ApplicationViewComponent
        slot_name :"tooltip-provider"

        attr_reader :delay_duration

        def initialize(delay_duration: 0, **attributes)
          @delay_duration = delay_duration
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{
            style: merged_style(CONTENTS_STYLE),
            "data-delay-duration" => delay_duration
          }.merge(defaults))
        end
      end
    end
  end
end
