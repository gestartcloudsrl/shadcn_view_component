# frozen_string_literal: true

module Shadcn
  module ContextMenu
    module Content
      # The panel. Its own class string rather than the dropdown's, for one
      # reason worth stating: the two differ only in which `--radix-*` custom
      # properties they read, and those are the properties `popper.js` writes
      # under the controller's `prefix`. Sharing the string would leave the
      # menu reading variables nothing sets.
      class Component < ApplicationViewComponent
        slot_name :"context-menu-content"

        style do
          base {
            "z-50 max-h-(--radix-context-menu-content-available-height) min-w-[8rem] " \
            "origin-(--radix-context-menu-content-transform-origin) overflow-x-hidden " \
            "overflow-y-auto rounded-md border bg-popover p-1 text-popover-foreground " \
            "shadow-md data-[side=bottom]:slide-in-from-top-2 " \
            "data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 " \
            "data-[side=top]:slide-in-from-bottom-2 data-[state=closed]:animate-out " \
            "data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 " \
            "data-[state=open]:animate-in data-[state=open]:fade-in-0 " \
            "data-[state=open]:zoom-in-95"
          }
        end

        def element_attributes(**defaults)
          super(**{
            role: "menu",
            hidden: true,
            "data-state" => "closed",
            "data-shadcn--dropdown-menu-target" => "content",
            "data-action" => "keydown->shadcn--dropdown-menu#contentKeydown"
          }.merge(defaults))
        end
      end
    end
  end
end
