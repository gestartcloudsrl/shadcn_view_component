# frozen_string_literal: true

module Shadcn
  module Select
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      def searchable
        render_with_template
      end

      def scrollable
        render_with_template
      end

      # Upstream's "Disabled" — as a disabled *item*, which is the half a listbox has to answer for — and "Invalid".
      def states
        render_with_template
      end
    end
  end
end
