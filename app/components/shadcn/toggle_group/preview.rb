# frozen_string_literal: true

module Shadcn
  module ToggleGroup
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # Upstream's "Size", "Vertical" and "Disabled".
      def sizes
        render_with_template
      end
    end
  end
end
