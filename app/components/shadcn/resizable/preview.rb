# frozen_string_literal: true

module Shadcn
  module Resizable
    class Preview < ApplicationViewComponentPreview
      # Upstream's own first example: two panels side by side.
      def default
        render_with_template
      end

      # Upstream's "Vertical".
      def vertical
        render_with_template
      end

      # Upstream's "With Handle", and a nested group — a row inside a column,
      # which is the layout the docs use to show both at once.
      def with_handle
        render_with_template
      end
    end
  end
end
