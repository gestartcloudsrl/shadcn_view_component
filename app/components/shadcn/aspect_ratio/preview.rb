# frozen_string_literal: true

module Shadcn
  module AspectRatio
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # Upstream's "Square" and "Portrait", beside the default's 16/9.
      def ratios
        render_with_template
      end
    end
  end
end
