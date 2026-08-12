# frozen_string_literal: true

module Shadcn
  module Sheet
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # Upstream's "No Close Button".
      def no_close_button
        render_with_template
      end
    end
  end
end
