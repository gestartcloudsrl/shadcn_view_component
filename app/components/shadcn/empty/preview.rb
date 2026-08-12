# frozen_string_literal: true

module Shadcn
  module Empty
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # Upstream's "Avatar" and "Avatar Group" — the media slot's other variant.
      def media
        render_with_template
      end
    end
  end
end
