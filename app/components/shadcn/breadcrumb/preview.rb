# frozen_string_literal: true

module Shadcn
  module Breadcrumb
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # Upstream's "Custom Separator".
      def custom_separator
        render_with_template
      end
    end
  end
end
