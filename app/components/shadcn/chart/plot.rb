# frozen_string_literal: true

module Shadcn
  module Chart
    # The arithmetic a cartesian chart needs, and nothing that draws.
    #
    # This is the part the pie did not have and the reason the todo said the
    # axis is the work: a bar is a rectangle, but *where* it goes is a scale, a
    # nice maximum, a set of ticks and a band per category. A plain object, so
    # all of that is asserted directly rather than through a browser — the same
    # trade `Calendar::Month` makes.
    #
    # `data` is a Hash of category to a Hash of series to number, which is what
    # a `group(:month, :platform).sum(:visits)` becomes after one `each_with_object`:
    #
    #   { "January" => { desktop: 186, mobile: 80 },
    #     "February" => { desktop: 305, mobile: 200 } }
    class Plot
      SIZE = { width: 560, height: 240 }.freeze
      # Room for the tick labels on the left and the category labels below.
      PADDING = { left: 34, right: 8, top: 12, bottom: 24 }.freeze
      TICKS = 4
      # The share of a band left empty, so neighbouring categories do not touch.
      INSET = 0.15

      attr_reader :data, :series, :stacked, :width, :height

      def initialize(data: {}, series: nil, stacked: false, width: SIZE[:width], height: SIZE[:height])
        @data = data.to_h { |category, values| [ category.to_s, values.to_h.transform_keys(&:to_s) ] }
        @series = (series || @data.values.flat_map(&:keys).uniq).map(&:to_s)
        @stacked = stacked
        @width = width
        @height = height
      end

      def categories = data.keys

      # The tallest thing the chart has to fit: one bar's value, or a whole
      # stack's, rounded up to something a person would choose as a maximum.
      def max
        @max ||= nice(data.values.map { |values| tallest(values) }.max.to_f)
      end

      def ticks = @ticks ||= (0..TICKS).map { |step| max * step / TICKS }

      # The horizontal room one category gets, including the space between.
      def band = @band ||= (plot_width / [ categories.size, 1 ].max.to_f)

      def x_of(index) = PADDING[:left] + band * index

      def y_of(value) = PADDING[:top] + (plot_height - plot_height * value.to_f / max)

      def baseline = y_of(0)

      def plot_width = width - PADDING[:left] - PADDING[:right]

      def plot_height = height - PADDING[:top] - PADDING[:bottom]

      # One rectangle per series per category. Grouped side by side, or stacked
      # one on top of the other — which is the same arithmetic with the bottom
      # moved up by what is already there.
      def bars
        data.flat_map.with_index do |(category, values), index|
          stacked ? stacked_bars(category, values, index) : grouped_bars(category, values, index)
        end
      end

      # Where a series' line goes. Not the middle of a band: a line's axis is a
      # *point* scale, so the first reading sits on the left edge and the last
      # on the right, and upstream's own line and area charts touch both. A bar
      # cannot — it needs a band to be wide in — which is why the two shapes
      # place their category labels differently.
      def point_x(index)
        return x_of(index) + band / 2 if categories.size < 2

        PADDING[:left] + plot_width * index / (categories.size - 1).to_f
      end

      def points(key)
        key = key.to_s

        data.map.with_index do |(category, values), index|
          { category:, value: values[key],
            x: point_x(index).round(2), y: y_of(values[key]).round(2) }
        end
      end

      # Every label would collide long before a year of days fits, so only every
      # `n`th is drawn — `n` from the room the longest label needs against the
      # room a band gives it. Upstream's own charts rotate them instead; a Rails
      # app is likelier to pass twelve months than a thousand points, so this
      # stays a skip rather than a rotation.
      def label_every(pixels_per_character: 7)
        longest = categories.map { |category| category.length }.max.to_i

        [ ((longest * pixels_per_character) / band).ceil, 1 ].max
      end

      private

      def tallest(values)
        stacked ? series.sum { |key| values[key].to_f } : values.values.map(&:to_f).max.to_f
      end

      def grouped_bars(category, values, index)
        gutter = band * INSET
        slot = (band - gutter * 2) / [ series.size, 1 ].max

        series.each_with_index.map do |key, position|
          value = values[key]
          top = y_of(value)

          bar(category:, key:, value:,
              x: (x_of(index) + gutter + slot * position).round(2), y: top.round(2),
              width: slot.round(2), height: (baseline - top).round(2))
        end
      end

      def stacked_bars(category, values, index)
        gutter = band * INSET
        bottom = baseline

        series.map do |key|
          value = values[key]
          height = plot_height * value.to_f / max
          bottom -= height

          bar(category:, key:, value:,
              x: (x_of(index) + gutter).round(2), y: bottom.round(2),
              width: (band - gutter * 2).round(2), height: height.round(2))
        end
      end

      def bar(**attributes) = attributes

      # A maximum a person would have chosen: the next round number above the
      # tallest value, so the ticks read 0, 100, 200 rather than 0, 78.5, 157.
      def nice(value)
        return 1 if value <= 0

        step = 10**Math.log10(value).floor

        (value / step).ceil * step
      end
    end
  end
end
