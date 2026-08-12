# frozen_string_literal: true

module Shadcn
  module Toaster
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # Rendered with the page, which is what a Rails flash does.
      def from_the_server
        render_with_template
      end
    end
  end
end
