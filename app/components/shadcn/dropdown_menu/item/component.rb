# frozen_string_literal: true

module Shadcn
  module DropdownMenu
    module Item
      # DropdownMenuItem
      class Component < ApplicationViewComponent
        slot_name :"dropdown-menu-item"

        style do
          base {
            "relative flex cursor-default items-center gap-2 rounded-sm px-2 py-1.5 text-sm " \
            "outline-hidden select-none focus:bg-accent focus:text-accent-foreground " \
            "data-[disabled]:pointer-events-none data-[disabled]:opacity-50 " \
            "data-[inset]:pl-8 data-[variant=destructive]:text-destructive " \
            "data-[variant=destructive]:focus:bg-destructive/10 " \
            "data-[variant=destructive]:focus:text-destructive " \
            "dark:data-[variant=destructive]:focus:bg-destructive/20 " \
            "[&_svg]:pointer-events-none [&_svg]:shrink-0 " \
            "[&_svg:not([class*='size-'])]:size-4 " \
            "[&_svg:not([class*='text-'])]:text-muted-foreground " \
            "data-[variant=destructive]:*:[svg]:text-destructive!"
          }
        end

        attr_reader :variant, :inset, :disabled

        def initialize(variant: :default, inset: false, disabled: false, **attributes)
          @variant = variant&.to_sym || :default
          @inset = inset
          @disabled = disabled
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{
            role: "menuitem",
            tabindex: "-1",
            "data-variant" => variant,
            "data-inset" => (true if inset),
            "data-disabled" => (true if disabled),
            "data-shadcn--dropdown-menu-target" => "item",
            "data-action" => "click->shadcn--dropdown-menu#select " \
                             "pointerenter->shadcn--dropdown-menu#pointerenter"
          }.merge(defaults))
        end
      end
    end
  end
end
