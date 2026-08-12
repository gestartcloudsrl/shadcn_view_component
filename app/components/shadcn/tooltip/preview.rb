# frozen_string_literal: true

module Shadcn
  module Tooltip
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # Upstream's "Side": the same tooltip on each of the four edges.
      def sides
        render_with_template
      end

      # Upstream's "With Keyboard Shortcut".
      def with_keyboard_shortcut
        render_with_template
      end
    end
  end
end
