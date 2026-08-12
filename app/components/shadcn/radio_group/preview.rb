# frozen_string_literal: true

module Shadcn
  module RadioGroup
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # Upstream's "Disabled" and "Invalid".
      def states
        render_with_template
      end
    end
  end
end
