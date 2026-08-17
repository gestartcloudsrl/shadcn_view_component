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

        # This field has to carry its own name, and that is **ours** rather than
        # upstream's — the same correction Select, Checkbox, Switch and the
        # Combobox trigger each needed here.
        #
        # It is not theoretical. The only name this input had was its
        # `placeholder`, and in multiple mode the controller blanks that once
        # there are chips — which upstream's own example also does. The field
        # was then a `role="combobox"` with no name at all, and axe failed it as
        # `label`, critical. Caught by the accessibility spec on the run *after*
        # the placeholder was wired up; the run before it could not see the
        # interaction, because nothing blanked the placeholder yet.
        #
        # The caller's placeholder is used when there is one, because "Add a
        # language…" names the field better than anything this gem could
        # generate. Read at render time and never touched again, so the name
        # stays put while the placeholder comes and goes.
        def element_attributes(**defaults)
          super(**{ "aria-label" => placeholder.presence || shadcn_t("combobox.add") }.merge(defaults))
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
