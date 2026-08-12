# frozen_string_literal: true

module Shadcn
  module Sidebar
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # Upstream's `floating` and `inset` variants, which the default preview
      # does not show.
      def variants
        render_with_template
      end
    end
  end
end
