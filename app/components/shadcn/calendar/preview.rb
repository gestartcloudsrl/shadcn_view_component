# frozen_string_literal: true

module Shadcn
  module Calendar
    class Preview < ApplicationViewComponentPreview
      # Upstream's own first example, minus the border it wraps it in: a single
      # month with today selected.
      def default
        render_with_template
      end

      # Upstream's "Month and Year Selector".
      def dropdown_caption
        render_with_template
      end
    end
  end
end
