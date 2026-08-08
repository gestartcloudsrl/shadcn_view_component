# frozen_string_literal: true

module Shadcn
  module Popover
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # The case the layering has to survive: an ancestor that creates a
      # stacking context.
      def inside_stacking_context
        render_with_template
      end

      # The other ancestor hazard: `transform`, `filter` and `contain` each
      # become the containing block for a fixed descendant.
      def inside_containing_block
        render_with_template
      end
    end
  end
end
