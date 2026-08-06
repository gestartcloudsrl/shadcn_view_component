# frozen_string_literal: true

module Shadcn
  module Select
    module Item
      # SelectItem
      class Component < ApplicationViewComponent
        INDICATOR_CLASSES = "absolute right-2 flex size-3.5 items-center justify-center"

        slot_name :"select-item"

        style do
          base {
            "relative flex w-full cursor-default items-center gap-2 rounded-sm py-1.5 pr-8 " \
            "pl-2 text-sm outline-hidden select-none focus:bg-accent " \
            "focus:text-accent-foreground data-[disabled]:pointer-events-none " \
            "data-[disabled]:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 " \
            "[&_svg:not([class*='size-'])]:size-4 " \
            "[&_svg:not([class*='text-'])]:text-muted-foreground " \
            "*:[span]:last:flex *:[span]:last:items-center *:[span]:last:gap-2"
          }
        end

        attr_reader :value, :selected, :disabled

        def initialize(value:, selected: false, disabled: false, **attributes)
          @value = value.to_s
          @selected = selected
          @disabled = disabled
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{
            role: "option",
            tabindex: "-1",
            "aria-selected" => selected.to_s,
            "data-value" => value,
            "data-state" => (selected ? "checked" : "unchecked"),
            "data-disabled" => (true if disabled),
            "data-shadcn--select-target" => "item",
            "data-action" => "click->shadcn--select#select " \
                             "pointerenter->shadcn--select#pointerenter"
          }.merge(defaults))
        end

        def call
          render_element(body: safe_join([ indicator, item_text ]))
        end

        private

        def indicator
          tag.span(
            tag.span(
              render(Icon::Component.new("check", class: "size-4")),
              hidden: (true unless selected)
            ),
            "data-slot": "select-item-indicator",
            class: INDICATOR_CLASSES
          )
        end

        def item_text
          tag.span(content, "data-slot": "select-item-text")
        end
      end
    end
  end
end
