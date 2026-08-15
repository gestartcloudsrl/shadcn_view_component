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

      # Upstream's "Bar Chart - Multiple", and the first shape here with an axis
      # under it.
      def bar
        render_with_template
      end

      # Upstream's "Bar Chart - Stacked": one bar a month, split by device.
      def bar_stacked
        render_with_template
      end

      # Upstream's "Line Chart - Multiple".
      def line
        render_with_template
      end

      # Upstream's "Area Chart".
      def area
        render_with_template
      end
    end
  end
end
