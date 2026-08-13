# frozen_string_literal: true

module Shadcn
  module Chart
    class Preview < ApplicationViewComponentPreview
      # Upstream's "Pie Chart" example, drawn here rather than by recharts.
      def default
        render_with_template
      end

      # Upstream's "Pie Chart - Donut", and the shape most of its own examples
      # use: `inner_radius:` is a fraction of the radius.
      def donut
        render_with_template
      end

      # What a pie is usually asked — how much of the whole — with the share in
      # the tooltip instead of the count.
      def percentages
        render_with_template
      end
    end
  end
end
