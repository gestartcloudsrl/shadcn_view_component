# frozen_string_literal: true

module Shadcn
  module Menubar
    module SubTrigger
      # Its own file for two differences from the dropdown's, both one token
      # wide and both upstream's: `outline-none` where the dropdown writes
      # `outline-hidden`, and a chevron sized `h-4 w-4` where the dropdown
      # writes `size-4` (menubar.tsx:238). The same size, spelled differently —
      # and `parity_spec` compares tokens, so the spelling is the port.
      class Component < Shadcn::DropdownMenu::SubTrigger::Component
        slot_name :"menubar-sub-trigger"

        style do
          base {
            "flex cursor-default items-center rounded-sm px-2 py-1.5 text-sm " \
            "outline-none select-none focus:bg-accent focus:text-accent-foreground " \
            "data-[inset]:pl-8 data-[state=open]:bg-accent " \
            "data-[state=open]:text-accent-foreground"
          }
        end

        private

        def chevron
          render(Icon::Component.new("chevron-right", class: "ml-auto h-4 w-4"))
        end
      end
    end
  end
end
