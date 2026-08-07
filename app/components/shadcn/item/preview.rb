# frozen_string_literal: true

module Shadcn
  module Item
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      def outline
        render_with_template
      end
    end
  end
end
