# frozen_string_literal: true

module Shadcn
  module DropdownMenu
    module CheckboxItem
      # DropdownMenuCheckboxItem
      class Component < ApplicationViewComponent
        INDICATOR_CLASSES = "pointer-events-none absolute left-2 flex size-3.5 " \
                            "items-center justify-center"

        slot_name :"dropdown-menu-checkbox-item"

        style do
          base {
            "relative flex cursor-default items-center gap-2 rounded-sm py-1.5 pr-2 pl-8 " \
            "text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground " \
            "data-[disabled]:pointer-events-none data-[disabled]:opacity-50 " \
            "[&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4"
          }
        end

        attr_reader :checked, :disabled

        def initialize(checked: false, disabled: false, **attributes)
          @checked = checked
          @disabled = disabled
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{
            role: "menuitemcheckbox",
            tabindex: "-1",
            "aria-checked" => checked.to_s,
            "data-state" => (checked ? "checked" : "unchecked"),
            "data-disabled" => (true if disabled),
            "data-shadcn--dropdown-menu-target" => "item",
            "data-action" => "click->shadcn--dropdown-menu#select " \
                             "pointerenter->shadcn--dropdown-menu#pointerenter"
          }.merge(defaults))
        end

        def call
          render_element(body: safe_join([ indicator, content ]))
        end

        private

        def indicator
          tag.span(class: INDICATOR_CLASSES) do
            tag.span(
              render(Icon::Component.new("check", class: "size-4")),
              "data-slot": "dropdown-menu-checkbox-item-indicator",
              hidden: (true unless checked)
            )
          end
        end
      end
    end
  end
end
