# frozen_string_literal: true

module Shadcn
  module Combobox
    module ChipInput
      # The field that sits *among* the chips rather than inside an InputGroup:
      # it takes whatever room is left on the last row.
      class Component < Shadcn::Combobox::Input::Component
        slot_name :"combobox-chip-input"

        style do
          base { "min-w-16 flex-1 outline-none" }
        end

        # No InputGroup and no addons: the chips box is the frame, and a chevron
        # would have nowhere to sit.
        def call
          render_element
        end
      end
    end
  end
end
