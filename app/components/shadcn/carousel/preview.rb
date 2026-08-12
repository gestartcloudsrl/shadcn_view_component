# frozen_string_literal: true

module Shadcn
  module Carousel
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # Upstream's "Sizes" and "Spacing": both are the caller's classes on the
      # item, which is why neither is an argument.
      def sizes
        render_with_template
      end

      # Upstream's "Orientation".
      def vertical
        render_with_template
      end
    end
  end
end
