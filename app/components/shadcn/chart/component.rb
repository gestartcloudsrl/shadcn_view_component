# frozen_string_literal: true

module Shadcn
  module Chart
    # Port of registry/new-york-v4/ui/chart.tsx — the half of it that is markup.
    #
    # `chart.tsx` draws nothing. It is a *frame*: a container that publishes one
    # custom property per series, and the contents of a tooltip and a legend
    # that `recharts` fills in. The chart itself — the SVG, the scales, the
    # axes — is `recharts`, 29,091 lines of compiled ES6 over eleven packages,
    # and the caller writes it in JSX.
    #
    # So this family is the frame ported 1:1 and the drawing written here. The
    # first shape drawn is the pie, because it is the one a Rails application
    # asks for most and the only one that needs no axes at all. See
    # [features/chart.md](../../../../.claude/docs/features/chart.md).
    #
    # `config:` is upstream's `ChartConfig`, key for key:
    #
    #   config: {
    #     chrome: { label: "Chrome", color: "var(--chart-1)" },
    #     safari: { label: "Safari", theme: { light: "…", dark: "…" } }
    #   }
    #
    # Every colour is published as `--color-<key>` on the container, which is
    # what lets a slice say `fill="var(--color-chrome)"` and a host restyle the
    # chart from its own stylesheet.
    class Component < ApplicationViewComponent
      THEMES = { light: "", dark: ".dark" }.freeze

      default_tag :div
      slot_name :chart

      style do
        base {
          # Upstream's own, minus thirteen `[&_.recharts-*]` variants: they
          # select `recharts`' DOM, which nothing here renders, so they would
          # compile to rules that match nothing. `parity_spec` holds them in
          # `allowed_missing` with that reason.
          #
          # `relative` is this port's: upstream's tooltip is positioned by
          # recharts inside a wrapper of its own, and here it is positioned
          # against the container.
          "relative flex aspect-video justify-center text-xs"
        }
      end

      renders_one :pie, ->(**options) { Pie::Component.new(config:, **options) }
      renders_one :chart_tooltip, ->(**options) { Tooltip::Component.new(**options) }
      renders_one :chart_legend, ->(**options) { Legend::Component.new(config:, **options) }

      attr_reader :config

      def initialize(config: {}, **attributes)
        @config = config.transform_keys(&:to_s)
        super(**attributes)
      end

      def element_attributes(**defaults)
        super(**{
          "data-chart" => chart_id,
          "data-controller" => "shadcn--chart"
        }.merge(defaults))
      end

      # Slots rather than block content, and rendered in an order this decides:
      # the tooltip has to come after the shape it floats over, and slot content
      # is emitted before block content — the trap that has shipped twice here.
      def call
        render_element(body: safe_join([ colours, stack, chart_tooltip ].compact))
      end

      private

      # Upstream's container is a flex *row* because it has exactly one child:
      # recharts draws the legend inside the SVG. Here the legend is its own
      # element, so the two need a column of their own — and it is a plain div
      # rather than a class on the container, which stays as `chart.tsx` wrote
      # it.
      def stack
        tag.div(safe_join([ pie, content, chart_legend ].compact),
                class: "flex w-full min-w-0 flex-col items-center justify-center gap-2")
      end

      def chart_id
        @chart_id ||= "chart-#{SecureRandom.hex(4)}"
      end

      # Upstream's `ChartStyle`, which is a real `<style>` element rather than
      # inline properties: a custom property has to be readable by descendants
      # *and* by a `.dark` rule, and an inline style cannot carry the second.
      def colours
        rules = THEMES.filter_map do |theme, prefix|
          declarations = config.filter_map do |key, item|
            colour = safe_colour(item.dig(:theme, theme) || item[:color])
            "  --color-#{key.parameterize.underscore.dasherize}: #{colour};" if colour
          end

          "#{prefix} [data-chart=#{chart_id}] {\n#{declarations.join("\n")}\n}" if declarations.any?
        end
        return if rules.empty?

        tag.style(rules.join("\n").html_safe) # rubocop:disable Rails/OutputSafety
      end

      # A colour reaches a `<style>` element, where a `}` would end the rule and
      # everything after it would be the caller's own CSS running in the host's
      # page. Upstream writes the same string through
      # `dangerouslySetInnerHTML` and is exposed to exactly this; a library that
      # runs inside an application it cannot see does not get to be.
      #
      # What is allowed is what a colour is made of: `oklch(0.7 0.1 20)`,
      # `var(--chart-1)`, `#0f172a`, `rgb(1 2 3 / 40%)`.
      COLOUR = %r{\A[\w\s().,%#/-]+\z}

      def safe_colour(value)
        value.to_s.strip.presence&.then { |colour| colour if colour.match?(COLOUR) }
      end
    end
  end
end
