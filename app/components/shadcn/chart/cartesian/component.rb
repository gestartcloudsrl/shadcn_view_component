# frozen_string_literal: true

module Shadcn
  module Chart
    module Cartesian
      # What a bar, a line and an area all need and the pie did not: a grid, an
      # axis down the left, category labels along the bottom, and one accessible
      # name carrying every number. Abstract — `shapes` is the subclass's half.
      #
      # **Ours**, like the pie: `chart.tsx` draws nothing, so there is no
      # upstream markup for this to be 1:1 with. What *is* reproduced is the
      # contract around it — every mark is filled from `--color-<key>`, which
      # the container publishes from `config`, so a host restyles this chart
      # from the same stylesheet that restyles upstream's.
      #
      # The axis is drawn in SVG attributes and CSS custom properties rather
      # than Tailwind classes. `stroke="var(--border)"` is a token `shadcn.css`
      # already defines, and it keeps the grid out of `reverse_parity_spec`'s
      # way: a class here would be one no vendored source contains, and every
      # such class has to be listed with its reason.
      class Component < ApplicationViewComponent
        default_tag :svg
        # No `slot_name` of its own: this class is never rendered, and a
        # `data-slot="chart-cartesian"` would name an element no page contains.
        # Each shape declares its own.

        style do
          base { "w-full" }
        end

        attr_reader :config, :label

        def initialize(data: {}, config: {}, series: nil, label: nil, **attributes)
          @data = data
          @series = series
          @config = config
          @label = label
          super(**attributes)
        end

        # The graphic says nothing at all, because the table beside it says all
        # of it. Everything inside an SVG is presentational to a screen reader
        # unless it is given a role and a name, and giving the marks either one
        # would make the chart speak twice — once as an image and once as data.
        #
        # `aria-hidden` is only safe while nothing inside can take focus: the
        # pair is what axe calls `aria-hidden-focus`, and it is the thing to
        # check first if a keyboard cursor over the marks is ever added.
        def element_attributes(**defaults)
          super(**{
            viewBox: "0 0 #{plot.width} #{plot.height}",
            "aria-hidden" => "true"
          }.merge(defaults))
        end

        # The grid goes down first so the shapes are drawn over it, which is the
        # one thing SVG's painter order decides for us. The table follows the
        # graphic it describes, which is the order a reader meets them in.
        def call
          safe_join([ render_element(body: safe_join([ grid, tick_labels, category_labels, *shapes ])), table ])
        end

        private

        # No rows, no table: an empty scope on a quiet week is a thing a host's
        # data does, and a table of nothing announces a name and then leaves a
        # reader in an empty grid.
        def table
          return if plot.categories.empty?

          render(Table::Component.new(caption: label, columns: plot.series.map { |key| label_for(key) },
                                      rows: table_rows))
        end

        def table_rows
          plot.data.map do |category, values|
            [ category, *plot.series.map { |key| number(values[key]) } ]
          end
        end

        def plot = @plot ||= Plot.new(data: @data, series: @series)

        def shapes = raise NotImplementedError, "#{self.class} draws no shape"

        def grid
          safe_join(plot.ticks.map do |value|
            y = plot.y_of(value).round(2)

            tag.line(x1: Plot::PADDING[:left], x2: plot.width - Plot::PADDING[:right], y1: y, y2: y,
                     stroke: "var(--border)", "stroke-dasharray": ("3 3" unless value.zero?))
          end)
        end

        def tick_labels
          safe_join(plot.ticks.map do |value|
            tag.text(number(value), x: Plot::PADDING[:left] - 6, y: (plot.y_of(value) + 3).round(2),
                                    "text-anchor": "end", **label_attributes)
          end)
        end

        # Only every `label_every`th, and the first is always drawn: a chart
        # whose axis starts at "Week 5" reads as though the data does.
        def category_labels
          every = plot.label_every

          safe_join(plot.categories.each_with_index.filter_map do |category, index|
            next unless (index % every).zero?

            x = category_x(index)

            tag.text(category, x: x.round(2), y: plot.height - 8,
                               "text-anchor": anchor_at(x), **label_attributes)
          end)
        end

        # Under the middle of the band, which is where a bar stands. A line
        # chart puts its readings on a point scale instead and says so.
        def category_x(index) = plot.x_of(index) + plot.band / 2

        # A label centred on a reading that sits on the edge of the plot has
        # half of itself outside the viewBox, and an SVG clips at its own box:
        # the line chart's "June" was drawn as "Jun". Only a point scale reaches
        # the edge, so this changes nothing for a bar.
        def anchor_at(x)
          return "start" if x <= Plot::PADDING[:left]
          return "end" if x >= plot.width - Plot::PADDING[:right]

          "middle"
        end

        def label_attributes = { fill: "var(--muted-foreground)", "font-size": 10 }

        # What every mark hands the controller, so the tooltip is filled from
        # the DOM rather than from the series sent a second time as JSON.
        def mark_attributes(category:, key:, value:)
          {
            "data-shadcn--chart-target": "mark",
            "data-action": "pointerenter->shadcn--chart#show pointermove->shadcn--chart#move " \
                           "pointerleave->shadcn--chart#hide",
            "data-key": key,
            "data-label": category,
            "data-name": label_for(key),
            "data-display": number(value)
          }
        end

        def colour_of(key) = "var(--color-#{key.to_s.parameterize.underscore.dasherize})"

        def label_for(key) = config.dig(key.to_sym, :label) || config.dig(key.to_s, :label) || key.to_s.humanize

        # `|| 0` because a series may be missing from a category — a month
        # where nothing was sold is a gap in the Hash, not a zero someone typed.
        def number(value) = ActiveSupport::NumberHelper.number_to_delimited(value || 0)
      end
    end
  end
end
