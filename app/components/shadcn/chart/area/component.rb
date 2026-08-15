# frozen_string_literal: true

module Shadcn
  module Chart
    module Area
      # Upstream's "Area Chart": the line chart with the space beneath each
      # series filled in.
      #
      #   chart.with_area(data: { "January" => { desktop: 186, mobile: 80 } })
      class Component < Line::Component
        # Flat, and see-through enough that two overlapping series both stay
        # readable. Upstream's docs example fills from a `<linearGradient>`
        # instead: that needs a `<defs>` with an id per series, and an id that
        # has to stay unique in a page this gem cannot see is a cost the fill
        # does not repay.
        OPACITY = 0.4

        slot_name :"chart-area"

        private

        # The fills go down before every line and dot, or a series drawn later
        # would wash out the one before it.
        def shapes = plot.series.map { |key| fill(key) } + super

        def fill(key)
          tag.polygon(points: closed(key), fill: colour_of(key), "fill-opacity": OPACITY)
        end

        # A line, then back along the baseline to where it started — the two
        # corners that turn a stroke into a shape.
        def closed(key)
          points = plot.points(key)
          return "" if points.empty?

          [ "#{points.first[:x]},#{plot.baseline.round(2)}",
            *points.map { |point| "#{point[:x]},#{point[:y]}" },
            "#{points.last[:x]},#{plot.baseline.round(2)}" ].join(" ")
        end
      end
    end
  end
end
