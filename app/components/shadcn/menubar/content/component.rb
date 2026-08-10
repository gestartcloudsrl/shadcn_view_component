# frozen_string_literal: true

module Shadcn
  module Menubar
    module Content
      # A menu's panel. Wider than the dropdown's (`min-w-[12rem]` against
      # `min-w-[8rem]`), and it reads `--radix-menubar-*`, which is why it is
      # written out rather than inherited.
      #
      # It carries no `data-[state=closed]:animate-out`, which the dropdown's
      # does. That is upstream's string as vendored, not an omission here.
      class Component < ApplicationViewComponent
        slot_name :"menubar-content"

        style do
          base {
            "z-50 min-w-[12rem] origin-(--radix-menubar-content-transform-origin) " \
            "overflow-hidden rounded-md border bg-popover p-1 text-popover-foreground " \
            "shadow-md data-[side=bottom]:slide-in-from-top-2 " \
            "data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 " \
            "data-[side=top]:slide-in-from-bottom-2 data-[state=closed]:fade-out-0 " \
            "data-[state=closed]:zoom-out-95 data-[state=open]:animate-in " \
            "data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95"
          }
        end

        def element_attributes(**defaults)
          super(**{
            role: "menu",
            # Neither is upstream's markup — Radix's FocusScope and Menu add
            # them at runtime, which is why they are in the dropdown's content
            # and not in either vendored file. The `tabindex` is load-bearing:
            # without it `focus()` on the panel is silently a no-op, so the
            # panel never holds the focus, and Escape, the typeahead and the
            # arrow keys are all left listening on an element nothing types
            # into.
            tabindex: "-1",
            "aria-orientation" => "vertical",
            hidden: true,
            "data-state" => "closed",
            "data-shadcn--dropdown-menu-target" => "content",
            "data-action" => "keydown->shadcn--dropdown-menu#contentKeydown " \
                             "keydown->shadcn--menubar#contentKeydown"
          }.merge(defaults))
        end
      end
    end
  end
end
