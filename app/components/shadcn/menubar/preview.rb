# frozen_string_literal: true

module Shadcn
  module Menubar
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # Upstream's "Radio" and "With Icons".
      def items
        render_with_template
      end
    end
  end
end
