# frozen_string_literal: true

module Shadcn
  module ButtonGroup
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      def vertical
        render_with_template
      end
    end
  end
end
