# frozen_string_literal: true

module Shadcn
  module HoverCard
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # Upstream's "Sides" and "Trigger Delays".
      def sides
        render_with_template
      end
    end
  end
end
