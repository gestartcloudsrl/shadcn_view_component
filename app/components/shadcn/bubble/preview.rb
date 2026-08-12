# frozen_string_literal: true

module Shadcn
  module Bubble
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # Upstream's "Alignment" and "Links and Buttons".
      def alignment
        render_with_template
      end
    end
  end
end
