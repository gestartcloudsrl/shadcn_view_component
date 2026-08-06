# frozen_string_literal: true

module Shadcn
  module DropdownMenu
    module SubTrigger
      # DropdownMenuSubTrigger — a menu item that opens the nested menu.
      class Component < ApplicationViewComponent
        slot_name :"dropdown-menu-sub-trigger"

        style do
          base {
            "flex cursor-default items-center gap-2 rounded-sm px-2 py-1.5 text-sm " \
            "outline-hidden select-none focus:bg-accent focus:text-accent-foreground " \
            "data-[inset]:pl-8 data-[state=open]:bg-accent " \
            "data-[state=open]:text-accent-foreground [&_svg]:pointer-events-none " \
            "[&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 " \
            "[&_svg:not([class*='text-'])]:text-muted-foreground"
          }
        end

        attr_reader :inset, :disabled

        def initialize(inset: false, disabled: false, **attributes)
          @inset = inset
          @disabled = disabled
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{
            role: "menuitem",
            tabindex: "-1",
            "aria-haspopup" => "menu",
            "aria-expanded" => "false",
            "data-state" => "closed",
            "data-inset" => (true if inset),
            "data-disabled" => (true if disabled),
            "data-shadcn--dropdown-menu-target" => "trigger",
            "data-action" => "click->shadcn--dropdown-menu#toggle " \
                             "keydown->shadcn--dropdown-menu#triggerKeydown " \
                             "pointerenter->shadcn--dropdown-menu#open"
          }.merge(defaults))
        end

        def call
          render_element(body: safe_join([ content, chevron ]))
        end

        private

        def chevron
          render(Icon::Component.new("chevron-right", class: "ml-auto size-4"))
        end
      end
    end
  end
end
