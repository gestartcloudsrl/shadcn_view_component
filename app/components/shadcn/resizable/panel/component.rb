# frozen_string_literal: true

module Shadcn
  module Resizable
    module Panel
      # One panel. Upstream carries no classes at all — the package writes an
      # inline style — so what is reproduced here is that style, minus the part
      # of it that resets borders and padding the package cannot know a caller
      # wants.
      #
      # A size is a share, not a pixel: `flex-grow` against `flex-basis: 0` is
      # exactly the proportional layout the package computes, which is why the
      # browser does the resizing and the controller only writes two numbers.
      class Component < ApplicationViewComponent
        default_tag :div
        slot_name :"resizable-panel"

        attr_reader :default_size, :min_size, :max_size

        # Sizes are percentages, as upstream's are. Give every panel one or give
        # none: with a mix, the ones without would each take a single share
        # against another's twenty-five, which is not what anybody means.
        def initialize(default_size: nil, min_size: nil, max_size: nil, **attributes)
          @default_size = default_size
          @min_size = min_size
          @max_size = max_size
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{
            id: panel_id,
            "data-shadcn--resizable-target" => "panel",
            "data-min-size" => min_size,
            "data-max-size" => max_size,
            style: merged_style(
              "flex-basis:0;flex-shrink:1;flex-grow:#{default_size || 1};overflow:hidden;" \
              "display:flex;min-width:0;min-height:0"
            )
          }.compact.merge(defaults))
        end

        private

        # A handle points at the panel before it with `aria-controls`, so a
        # panel needs a name of its own even when the caller gives it none.
        def panel_id
          attributes[:id] || "shadcn-resizable-panel-#{SecureRandom.hex(4)}"
        end
      end
    end
  end
end
