# frozen_string_literal: true

module Shadcn
  module Avatar
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # An image that never arrives, which is the case the controller exists to
      # handle and the one `default` cannot carry — see the template.
      def fallback
        render_with_template
      end
    end
  end
end
