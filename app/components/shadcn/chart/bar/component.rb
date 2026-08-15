# frozen_string_literal: true

module Shadcn
  module Chart
    module Bar
      # Upstream's "Bar Chart" and "Bar Chart - Stacked", drawn on the server.
      #
      #   chart.with_bar(data: { "January" => { desktop: 186, mobile: 80 } })
      #
      # `data:` is a Hash of category to a Hash of series to number — one
      # `each_with_object` away from `group(:month, :platform).sum(:visits)`.
      class Component < Cartesian::Component
        # `radius={4}`, which upstream's bar examples pass at the call site in
        # the docs. Nothing of recharts is vendored here, so unlike a class
        # string this is checked against the rendered example and not against
        # `vendor/`.
        RADIUS = 4

        slot_name :"chart-bar"

        attr_reader :stacked

        # `stacked:` lives here and not on the frame because it is a bar's
        # question. A stacked *line* would need cumulative points, and `Plot`
        # does not compute them — so the option is absent where it would lie.
        def initialize(stacked: false, **attributes)
          @stacked = stacked
          super(**attributes)
        end

        private

        def plot = @plot ||= Plot.new(data: @data, series: @series, stacked:)

        # A `<rect>` rounds all four corners or none, because `rx` takes one
        # number. A stack needs its seams square and only its two ends round,
        # which is the per-corner form of the same prop. So a bar is a path,
        # like the pie's slices.
        def shapes
          plot.bars.group_by { |bar| bar[:category] }.values.flat_map do |bars|
            bars.map.with_index do |bar, position|
              tag.path(d: outline(bar, **corners(position, bars.size)), fill: colour_of(bar[:key]),
                       **mark_attributes(**bar.slice(:category, :key, :value)))
            end
          end
        end

        # Grouped, every bar stands on its own and rounds both ends. Stacked,
        # only the bottom of the first segment and the top of the last are on
        # the outside of anything.
        def corners(position, count)
          return { top: true, bottom: true } unless stacked

          { top: position == count - 1, bottom: position.zero? }
        end

        # One formula for all four cases: a zero-radius arc is drawn as a
        # straight line, which is the SVG spec's own answer to `A 0 0`.
        def outline(bar, top:, bottom:)
          radius = [ RADIUS, bar[:width] / 2.0, bar[:height] / 2.0 ].min.round(2)
          t = top ? radius : 0
          b = bottom ? radius : 0
          x, y = bar.values_at(:x, :y)
          right = (x + bar[:width]).round(2)
          base = (y + bar[:height]).round(2)

          "M #{x} #{(y + t).round(2)} A #{t} #{t} 0 0 1 #{(x + t).round(2)} #{y} " \
            "L #{(right - t).round(2)} #{y} A #{t} #{t} 0 0 1 #{right} #{(y + t).round(2)} " \
            "L #{right} #{(base - b).round(2)} A #{b} #{b} 0 0 1 #{(right - b).round(2)} #{base} " \
            "L #{(x + b).round(2)} #{base} A #{b} #{b} 0 0 1 #{x} #{(base - b).round(2)} Z"
        end
      end
    end
  end
end
