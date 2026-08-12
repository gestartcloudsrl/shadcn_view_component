# frozen_string_literal: true

module Shadcn
  module Table
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # Upstream's "Footer": a `<tfoot>` totalling the rows above it.
      def footer
        render_with_template
      end
    end
  end
end
