# frozen_string_literal: true

module Shadcn
  module Checkbox
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # Upstream's "Checked State" and "Invalid State", with indeterminate beside them.
      def states
        render_with_template
      end
    end
  end
end
