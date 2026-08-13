# frozen_string_literal: true

module Shadcn
  module Chart
    module Tooltip
      # `ChartTooltipContent`, 1:1 in markup.
      #
      # Upstream's is rendered by recharts each time the pointer moves, with the
      # hovered item's payload. Here it is rendered once, empty, and the
      # controller writes the label, the name, the value and the indicator's
      # colour into it — which is the same DOM, arrived at from the other side.
      #
      # `indicator:` is upstream's `dot | line | dashed`, and the classes for
      # all three come from `chart.tsx`.
      class Component < ApplicationViewComponent
        INDICATORS = {
          dot: "h-2.5 w-2.5",
          line: "w-1",
          dashed: "w-0 border-[1.5px] border-dashed bg-transparent"
        }.freeze

        default_tag :div
        slot_name :"chart-tooltip"

        style do
          base {
            "grid min-w-[8rem] items-start gap-1.5 rounded-lg border border-border/50 bg-background " \
            "px-2.5 py-1.5 text-xs shadow-xl"
          }
        end

        attr_reader :indicator, :hide_label, :hide_indicator

        def initialize(indicator: :dot, hide_label: false, hide_indicator: false, **attributes)
          @indicator = INDICATORS.key?(indicator&.to_sym) ? indicator.to_sym : :dot
          @hide_label = hide_label
          @hide_indicator = hide_indicator
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{
            "data-shadcn--chart-target" => "tooltip",
            hidden: true,
            # Positioned against the container rather than by the wrapper
            # recharts renders and this port does not.
            style: merged_style("position:absolute;pointer-events:none")
          }.merge(defaults))
        end

        def call
          render_element(body: safe_join([ (heading unless nest_label?), items ].compact))
        end

        private

        # Upstream's `nestLabel`: with a single item and an indicator that is
        # not a dot, the label moves *inside* the row and the row bottom-aligns
        # (`chart.tsx:186`). A pie's tooltip is always a single item, so here it
        # is decided by the indicator alone.
        def nest_label? = !hide_label && indicator != :dot

        def heading
          return if hide_label

          tag.div(class: "font-medium", "data-shadcn--chart-target": "label")
        end

        def items
          tag.div(class: "grid gap-1.5") do
            tag.div(class: row_classes) do
              safe_join([ swatch, body ].compact)
            end
          end
        end

        def row_classes
          [
            "flex w-full flex-wrap items-stretch gap-2 [&>svg]:h-2.5 [&>svg]:w-2.5 [&>svg]:text-muted-foreground",
            ("items-center" if indicator == :dot)
          ].compact.join(" ")
        end

        def swatch
          return if hide_indicator

          classes = [
            "shrink-0 rounded-[2px] border-(--color-border) bg-(--color-bg)",
            INDICATORS[indicator],
            ("my-0.5" if nest_label? && indicator == :dashed)
          ].compact.join(" ")

          tag.div(class: classes, "data-shadcn--chart-target": "indicator")
        end

        def body
          tag.div(class: "flex flex-1 #{nest_label? ? 'items-end' : 'items-center'} justify-between leading-none") do
            safe_join([
              tag.div(class: "grid gap-1.5") do
                safe_join([ (heading if nest_label?),
                            tag.span(class: "text-muted-foreground", "data-shadcn--chart-target": "name") ].compact)
              end,
              tag.span(class: "font-mono font-medium text-foreground tabular-nums",
                       "data-shadcn--chart-target": "value")
            ])
          end
        end
      end
    end
  end
end
