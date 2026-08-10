# frozen_string_literal: true

module Shadcn
  module ContextMenu
    module SubContent
      # Its own class string rather than the dropdown's, and the reason is the
      # one thing `parity_spec` cannot see: the two differ only in which
      # `--radix-*` custom properties they read, and those are what `popper.js`
      # writes under the controller's prefix. Inheriting the dropdown's would
      # leave a context submenu reading variables nothing sets — and parity
      # would still pass, because it asks whether a token appears anywhere in
      # the family, not whether it appears on the right element.
      class Component < Shadcn::DropdownMenu::SubContent::Component
        slot_name :"context-menu-sub-content"

        style do
          base {
            "z-50 min-w-[8rem] origin-(--radix-context-menu-content-transform-origin) " \
            "overflow-hidden rounded-md border bg-popover p-1 text-popover-foreground " \
            "shadow-lg data-[side=bottom]:slide-in-from-top-2 " \
            "data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 " \
            "data-[side=top]:slide-in-from-bottom-2 data-[state=closed]:animate-out " \
            "data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 " \
            "data-[state=open]:animate-in data-[state=open]:fade-in-0 " \
            "data-[state=open]:zoom-in-95"
          }
        end
      end
    end
  end
end
