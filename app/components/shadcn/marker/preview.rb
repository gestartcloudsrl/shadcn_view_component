# frozen_string_literal: true

module Shadcn
  module Marker
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # Upstream's "Status" and "Shimmer" — and the only place in the gallery
      # that renders the `shimmer` utility.
      def status
        render_with_template
      end
    end
  end
end
