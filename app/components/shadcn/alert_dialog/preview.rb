# frozen_string_literal: true

module Shadcn
  module AlertDialog
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # Upstream's "Small", "Media", "Small with Media" and "Destructive".
      def small_with_media
        render_with_template
      end
    end
  end
end
