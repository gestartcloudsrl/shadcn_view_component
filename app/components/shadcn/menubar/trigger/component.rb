# frozen_string_literal: true

module Shadcn
  module Menubar
    module Trigger
      # One name on the bar.
      class Component < ApplicationViewComponent
        default_tag :button
        slot_name :"menubar-trigger"

        style do
          base {
            "flex items-center rounded-sm px-2 py-1 text-sm font-medium outline-hidden " \
            "select-none focus:bg-accent focus:text-accent-foreground " \
            "data-[state=open]:bg-accent data-[state=open]:text-accent-foreground"
          }
        end

        def element_attributes(**defaults)
          super(**{
            type: "button",
            role: "menuitem",
            "aria-haspopup" => "menu",
            "aria-expanded" => "false",
            "data-state" => "closed",
            "data-shadcn--dropdown-menu-target" => "trigger",
            "data-shadcn--menubar-target" => "trigger",
            # Two controllers listening to one element: the menu's, which opens
            # and closes it, and the bar's, which decides what the arrows do and
            # what a hover means while another menu is already open.
            "data-action" => "click->shadcn--dropdown-menu#toggle " \
                             "keydown->shadcn--dropdown-menu#triggerKeydown " \
                             "keydown->shadcn--menubar#keydown " \
                             "pointerenter->shadcn--menubar#pointerEnter " \
                             "focus->shadcn--menubar#focused"
          }.merge(defaults))
        end
      end
    end
  end
end
