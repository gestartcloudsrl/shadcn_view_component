# frozen_string_literal: true

module Shadcn
  module Sidebar
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # Upstream's `floating` variant. Its own page: the panel is `fixed`, so
      # two of them cannot share one.
      def floating
        render_with_template
      end

      # Upstream's `inset` variant, for the same reason.
      def inset
        render_with_template
      end
    end
  end
end
