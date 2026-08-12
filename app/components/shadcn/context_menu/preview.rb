# frozen_string_literal: true

module Shadcn
  module ContextMenu
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # Upstream's "Radio", "Destructive", "Icons" and "Groups".
      def items
        render_with_template
      end
    end
  end
end
