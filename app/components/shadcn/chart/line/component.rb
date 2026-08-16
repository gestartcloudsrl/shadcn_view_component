# frozen_string_literal: true

module Shadcn
  module Chart
    module Line
      # Upstream's "Line Chart", drawn on the server: one polyline per series,
      # with a dot at each reading.
      #
      #   chart.with_line(data: { "January" => { desktop: 186, mobile: 80 } })
      class Component < Cartesian::Component
        DOT = 4
        # The dot a pointer has to hit, which is not the dot a reader sees. Four
        # pixels is a target nobody can hold, so a transparent circle takes the
        # events and the visible one takes the colour.
        REACH = 10

        slot_name :"chart-line"

        private

        # A label belongs under the reading it names, and a line's readings run
        # edge to edge rather than band by band.
        def category_x(index) = plot.point_x(index)

        def shapes
          plot.series.flat_map { |key| [ path(key), *dots(key) ] }
        end

        def path(key)
          tag.polyline(points: coordinates(key), fill: "none", stroke: colour_of(key),
                       "stroke-width": 2, "stroke-linecap": "round", "stroke-linejoin": "round")
        end

        def coordinates(key)
          plot.points(key).map { |point| "#{point[:x]},#{point[:y]}" }.join(" ")
        end

        def dots(key)
          plot.points(key).flat_map do |point|
            [
              tag.circle(cx: point[:x], cy: point[:y], r: DOT, fill: colour_of(key)),
              tag.circle(cx: point[:x], cy: point[:y], r: REACH, fill: "transparent",
                         **mark_attributes(category: point[:category], key:, value: point[:value]))
            ]
          end
        end
      end
    end
  end
end
