# frozen_string_literal: true

module Shadcn
  module Chart
    module Legend
      # `ChartLegendContent`, 1:1 in markup.
      #
      # Upstream's is handed a payload by recharts' `Legend`; here it is the
      # `config` itself, which is the same list arrived at without a round trip
      # through a chart library.
      class Component < ApplicationViewComponent
        default_tag :div
        slot_name :"chart-legend"

        style do
          base { "flex items-center justify-center gap-4" }
        end

        attr_reader :config, :vertical_align, :hide_icon

        def initialize(config: {}, vertical_align: :bottom, hide_icon: false, **attributes)
          @config = config
          @vertical_align = vertical_align&.to_sym || :bottom
          @hide_icon = hide_icon
          super(**attributes)
        end

        def css_classes(extra = nil)
          super([ vertical_align == :top ? "pb-3" : "pt-3", extra ].compact.join(" ").presence)
        end

        def call
          render_element(body: safe_join(entries))
        end

        private

        def entries
          config.map do |key, item|
            tag.div(class: "flex items-center gap-1.5 [&>svg]:h-3 [&>svg]:w-3 [&>svg]:text-muted-foreground") do
              safe_join([ swatch(key), item[:label] ].compact)
            end
          end
        end

        def swatch(key)
          return if hide_icon

          tag.div(class: "h-2 w-2 shrink-0 rounded-[2px]",
                  style: "background-color: var(--color-#{key.to_s.parameterize.underscore.dasherize})")
        end
      end
    end
  end
end
