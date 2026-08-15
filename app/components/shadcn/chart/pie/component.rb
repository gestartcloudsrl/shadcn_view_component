# frozen_string_literal: true

module Shadcn
  module Chart
    module Pie
      # A pie, drawn on the server.
      #
      # **Ours.** `chart.tsx` has no markup for a shape — the caller writes
      # `<PieChart><Pie …/></PieChart>` and `recharts` renders it. What is
      # reproduced instead is the *contract* around it: each slice is filled
      # from `--color-<key>`, which the container publishes from `config`, so
      # the same stylesheet that themes upstream's chart themes this one.
      #
      # An arc is trigonometry and an SVG path, which is why the pie is the
      # shape to draw first: no scales, no ticks, no axis labels to collide.
      #
      #   render(Shadcn::Chart::Component.new(config:)) do |chart|
      #     chart.with_pie(data: { chrome: 275, safari: 200, firefox: 187 })
      #   end
      #
      # `data:` is a Hash of key to number, which is what `group(:x).sum(:y)`
      # already hands back.
      class Component < ApplicationViewComponent
        SIZE = 250
        PADDING = 4
        # Twelve o'clock, where a reader starts. SVG angles start at three.
        START = -90

        default_tag :svg
        slot_name :"chart-pie"

        style do
          base { "mx-auto aspect-square max-h-[250px]" }
        end

        attr_reader :data, :config, :inner_radius, :percentage, :label

        # `inner_radius:` is a fraction of the radius, as upstream's own
        # examples pass one — 0 is a pie and 0.6 is the donut the docs show.
        def initialize(data: {}, config: {}, inner_radius: 0, percentage: false, label: nil, **attributes)
          @data = data.to_h.transform_keys(&:to_s).select { |_, value| value.to_f.positive? }
          @config = config
          @inner_radius = inner_radius.to_f.clamp(0, 0.95)
          @percentage = percentage
          @label = label
          super(**attributes)
        end

        # One image with one text alternative, which is what `role="img"`
        # means: everything inside it is presentational to a screen reader, so
        # the name has to carry the data or the data is gone. A slice cannot
        # carry its own — `aria-label` on a `<path>` with no role is prohibited,
        # and axe says so.
        #
        # `aria-label` and **not** an SVG `<title>`, which would say the same
        # thing and then be drawn by the browser as a native tooltip on every
        # hover — over this component's own. Reported from a screenshot: the
        # grey box covering the panel was Chrome's, not ours.
        def element_attributes(**defaults)
          super(**{ viewBox: "0 0 #{SIZE} #{SIZE}" }.merge(naming).merge(defaults))
        end

        def call
          render_element(body: safe_join(slices))
        end

        private

        # A pie of nothing draws nothing, and a `role="img"` with no name is
        # what axe calls `svg-img-alt`. A filtered scope reaches this.
        def naming
          return { "aria-hidden" => "true" } if description.blank?

          { role: "img", "aria-label" => description }
        end

        def total = @total ||= data.values.sum(&:to_f)

        # The whole chart in one sentence: its name, then every slice with the
        # number it stands for. A pie with fifty slices would read badly, and a
        # pie with fifty slices reads badly to everyone.
        def description
          slices = data.map { |key, value| "#{label_for(key)}: #{display_for(value, value.to_f / total)}" }

          [ label, slices.join(", ") ].compact.reject(&:empty?).join(" — ").presence
        end

        # Each slice carries what the tooltip needs, so the controller reads the
        # DOM rather than being handed the series a second time as JSON.
        def slices
          angle = START

          data.map do |key, value|
            share = value.to_f / total
            from = angle
            angle += share * 360

            tag.path(
              d: path_for(from, angle),
              fill: "var(--color-#{key.parameterize.underscore.dasherize})",
              "data-shadcn--chart-target": "mark",
              "data-action": "pointerenter->shadcn--chart#show pointermove->shadcn--chart#move " \
                             "pointerleave->shadcn--chart#hide",
              "data-key": key,
              "data-label": label_for(key),
              "data-display": display_for(value, share)
            )
          end
        end

        def label_for(key) = config.dig(key.to_sym, :label) || config.dig(key.to_s, :label) || key.to_s.humanize

        # What the tooltip shows. A share where one was asked for, because a
        # pie's question is usually "how much of the whole" — and doing it here
        # keeps the tooltip's own markup 1:1 with upstream, which has one cell
        # for a value and no room for a second number.
        def display_for(value, share)
          return "#{(share * 100).round(1).to_s.delete_suffix('.0')}%" if percentage

          ActiveSupport::NumberHelper.number_to_delimited(value)
        end

        def centre = SIZE / 2.0

        def radius = centre - PADDING

        # A full circle has no arc: its two ends are the same point, so the path
        # would draw nothing at all. One slice is the case a Rails application
        # reaches by filtering, not an odd one.
        def path_for(from, to)
          return ring if (to - from) >= 359.999

          outer_start = point(from, radius)
          outer_end = point(to, radius)
          large = (to - from) > 180 ? 1 : 0

          return "M #{centre} #{centre} L #{outer_start} A #{radius} #{radius} 0 #{large} 1 #{outer_end} Z" if hole.zero?

          inner_start = point(to, hole)
          inner_end = point(from, hole)

          "M #{outer_start} A #{radius} #{radius} 0 #{large} 1 #{outer_end} " \
            "L #{inner_start} A #{hole} #{hole} 0 #{large} 0 #{inner_end} Z"
        end

        def ring
          top = "#{centre} #{centre - radius}"
          bottom = "#{centre} #{centre + radius}"
          circle = "M #{top} A #{radius} #{radius} 0 1 1 #{bottom} A #{radius} #{radius} 0 1 1 #{top} Z"
          return circle if hole.zero?

          inner_top = "#{centre} #{centre - hole}"
          inner_bottom = "#{centre} #{centre + hole}"

          "#{circle} M #{inner_top} A #{hole} #{hole} 0 1 0 #{inner_bottom} A #{hole} #{hole} 0 1 0 #{inner_top} Z"
        end

        def hole = @hole ||= (radius * inner_radius).round(2)

        def point(degrees, distance)
          radians = degrees * Math::PI / 180

          "#{(centre + distance * Math.cos(radians)).round(2)} #{(centre + distance * Math.sin(radians)).round(2)}"
        end
      end
    end
  end
end
