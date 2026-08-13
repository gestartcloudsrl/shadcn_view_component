# frozen_string_literal: true

module Shadcn
  module Combobox
    module Clear
      # The X that empties the field. Upstream renders it through
      # `InputGroupButton` too, and hides the chevron whenever it is present —
      # which is what the trigger's
      # `group-has-data-[slot=combobox-clear]/input-group:hidden` does.
      class Component < Shadcn::InputGroup::Button::Component
        slot_name :"combobox-clear"

        def initialize(**attributes)
          super(variant: :ghost, size: :"icon-xs", **attributes)
        end

        def element_attributes(**defaults)
          super(**{
            "data-shadcn--combobox-target" => "clear",
            "data-action" => "click->shadcn--combobox#clear",
            tabindex: "-1",
            "aria-label" => shadcn_t("combobox.clear")
          }.merge(defaults))
        end

        def call
          render_element(body: render(Icon::Component.new("x", class: "pointer-events-none")))
        end
      end
    end
  end
end
