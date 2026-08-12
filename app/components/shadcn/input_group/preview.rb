# frozen_string_literal: true

module Shadcn
  module InputGroup
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # Upstream's "Icon", "Kbd", "Dropdown" and "Spinner" — what an addon holds,
      # where the default preview shows where an addon sits.
      def addons
        render_with_template
      end
    end
  end
end
