# frozen_string_literal: true

module Shadcn
  module NativeSelect
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # Upstream's "With Groups", "Disabled" and "Invalid".
      def groups
        render_with_template
      end
    end
  end
end
