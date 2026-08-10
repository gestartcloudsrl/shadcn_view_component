# frozen_string_literal: true

module Shadcn
  module Menubar
    module SubContent
      # A submenu's panel. Byte-identical to the dropdown's but for the
      # `--radix-*` prefix, which is exactly why it cannot be inherited: those
      # are the properties `popper.js` writes under the controller's prefix, and
      # borrowing the dropdown's string would leave this reading variables
      # nothing sets. `parity_spec` would not catch it — it asks whether a token
      # appears anywhere in the family, not whether it appears on the right
      # element.
      class Component < Shadcn::DropdownMenu::SubContent::Component
        slot_name :"menubar-sub-content"

        style do
          base {
            "z-50 min-w-[8rem] origin-(--radix-menubar-content-transform-origin) " \
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
