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

      # Upstream's "No Close Button": the corner dismiss left out.
      def no_close_button
        render_with_template
      end

      # Upstream's "Scrollable Content": a body that scrolls under a header and
      # footer that do not.
      def scrollable_content
        render_with_template
      end
    end
  end
end
