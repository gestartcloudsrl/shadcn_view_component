# frozen_string_literal: true

module Shadcn
  module Message
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end
    end
  end
end
