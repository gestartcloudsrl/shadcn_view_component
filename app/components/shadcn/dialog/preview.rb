# frozen_string_literal: true

module Shadcn
  module Dialog
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # The case the layering has to survive: a modal opened from inside an
      # ancestor that creates a stacking context.
      def inside_stacking_context
        render_with_template
      end
    end
  end
end
