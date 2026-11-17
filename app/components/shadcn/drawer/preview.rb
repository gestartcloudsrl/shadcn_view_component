# frozen_string_literal: true

module Shadcn
  module Drawer
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # The other three edges, which the same class string serves — only the
      # `data-vaul-drawer-direction` changes.
      def sides
        render_with_template
      end

      # A drawer taller than it can show, which is where the drag has to give
      # way to the scroll.
      def scrollable
        render_with_template
      end

      # The same list, in a drawer that closes sideways — where the two gestures
      # stop competing and the drag is let through whatever is scrolled.
      def scrollable_side
        render_with_template
      end

      # A Select and a DropdownMenu inside the panel. Their content is a layer
      # of its own in the top layer but still inside the drawer in the DOM, so
      # a press on one of its items reaches the drawer's drag.
      def with_layers
        render_with_template
      end
    end
  end
end
