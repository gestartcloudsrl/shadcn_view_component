# frozen_string_literal: true

module Shadcn
  module Tabs
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # Upstream's "Line" variant and its "Vertical" orientation.
      def line
        render_with_template
      end
    end
  end
end
