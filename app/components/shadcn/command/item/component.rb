# frozen_string_literal: true

module Shadcn
  module Command
    module Item
      # One option. `role="option"`, `aria-selected` for the virtual focus, and
      # `data-selected` for the classes — cmdk sets both, and shadcn's own
      # `data-[selected=true]:bg-accent` reads the second.
      class Component < ApplicationViewComponent
        default_tag :div
        slot_name :"command-item"

        style do
          base {
            "relative flex cursor-default items-center gap-2 rounded-sm px-2 py-1.5 text-sm " \
            "outline-hidden select-none data-[disabled=true]:pointer-events-none " \
            "data-[disabled=true]:opacity-50 data-[selected=true]:bg-accent " \
            "data-[selected=true]:text-accent-foreground [&_svg]:pointer-events-none [&_svg]:shrink-0 " \
            "[&_svg:not([class*='size-'])]:size-4 [&_svg:not([class*='text-'])]:text-muted-foreground"
          }
        end

        attr_reader :value, :keywords, :disabled, :selected

        # `value:` is what is searched where it is given, and the item's own text
        # otherwise — cmdk's rule. `keywords:` are searched too and never shown,
        # which is how "Preferences" is found by typing "settings".
        def initialize(value: nil, keywords: nil, disabled: false, selected: false, **attributes)
          @value = value
          @keywords = Array(keywords)
          @disabled = disabled
          @selected = selected
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{
            "cmdk-item" => "",
            id: item_id,
            role: "option",
            "aria-disabled" => (disabled.presence && "true"),
            "aria-selected" => selected.to_s,
            "data-disabled" => disabled.to_s,
            "data-selected" => selected.to_s,
            "data-value" => value,
            "data-keywords" => (keywords.join(" ").presence),
            "data-shadcn--command-target" => "item",
            "data-action" => "click->shadcn--command#choose pointermove->shadcn--command#hover"
          }.compact.merge(defaults))
        end

        private

        # An item needs a name of its own for `aria-activedescendant` to point
        # at it, and a caller has no reason to invent one.
        def item_id
          attributes[:id] || "shadcn-command-item-#{SecureRandom.hex(4)}"
        end
      end
    end
  end
end
