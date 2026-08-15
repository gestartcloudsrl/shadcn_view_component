# frozen_string_literal: true

module Shadcn
  module Combobox
    module Item
      # One option, with the tick that marks the chosen one. `data-highlighted`
      # is the virtual focus — Base UI and Radix agree on that name, which is
      # why the select's arrangement carries over unchanged.
      class Component < ApplicationViewComponent
        INDICATOR_CLASSES = "pointer-events-none absolute right-2 flex size-4 items-center justify-center"

        default_tag :div
        slot_name :"combobox-item"

        style do
          base {
            "relative flex w-full cursor-default items-center gap-2 rounded-sm py-1.5 pr-8 pl-2 text-sm " \
            "outline-hidden select-none data-highlighted:bg-accent data-highlighted:text-accent-foreground " \
            "data-[disabled]:pointer-events-none data-[disabled]:opacity-50 [&_svg]:pointer-events-none " \
            "[&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4"
          }
        end

        attr_reader :value, :label, :selected, :disabled

        def initialize(value: nil, label: nil, selected: false, disabled: false, **attributes)
          @value = value
          @label = label
          @selected = selected
          @disabled = disabled
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{
            id: item_id,
            role: "option",
            "aria-selected" => selected.to_s,
            "data-disabled" => (disabled.presence && ""),
            "data-value" => value,
            "data-label" => label,
            "data-shadcn--combobox-target" => "item",
            "data-action" => "click->shadcn--combobox#choose pointermove->shadcn--combobox#hover"
          }.compact.merge(defaults))
        end

        def call
          render_element(body: safe_join([ content, indicator ]))
        end

        private

        def indicator
          tag.span(
            render(Icon::Component.new("check", class: "pointer-events-none size-4 pointer-coarse:size-5")),
            class: INDICATOR_CLASSES,
            "data-slot": "combobox-item-indicator",
            hidden: !selected,
            "data-shadcn--combobox-target": "indicator"
          )
        end

        def item_id
          attributes[:id] || "shadcn-combobox-item-#{SecureRandom.hex(4)}"
        end
      end
    end
  end
end
