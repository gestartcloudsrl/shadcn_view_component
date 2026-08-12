# frozen_string_literal: true

module Shadcn
  module Input
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # Upstream's "Disabled", "Invalid", "File" and "Required", together: each is an attribute passed straight through rather than a variant.
      def states
        render_with_template
      end
    end
  end
end
