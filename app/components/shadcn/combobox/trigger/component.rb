# frozen_string_literal: true

module Shadcn
  module Combobox
    module Trigger
      # The chevron beside the field. Upstream renders it *through*
      # `InputGroupButton` with `asChild`, so the button's own classes land on
      # it — here that is a subclass, which is this gem's mapping for `asChild`.
      class Component < Shadcn::InputGroup::Button::Component
        ICON_CLASSES = "pointer-events-none size-4 text-muted-foreground"

        # `input-group-button`, not `combobox-trigger`: upstream's wrapper sets
        # the slot last and `asChild` merges the two into one element, so that
        # is the name the rendered button carries. Confirmed on the page rather
        # than reasoned about.
        slot_name :"input-group-button"

        def initialize(**attributes)
          super(variant: :ghost, size: :"icon-xs", **attributes)
        end

        def element_attributes(**defaults)
          super(**{
            role: "combobox",
            # Named, where upstream's is not. Its rendered trigger is a
            # `role="combobox"` with a chevron in it and no text at all, and a
            # role that takes a name and has none is what axe calls a
            # `button-name` violation — the same correction Select, Checkbox and
            # Switch needed here.
            "aria-label" => shadcn_t("combobox.toggle"),
            "aria-haspopup" => "dialog",
            "aria-expanded" => "false",
            tabindex: "0",
            "data-shadcn--combobox-target" => "trigger",
            "data-action" => "click->shadcn--combobox#toggle"
          }.merge(defaults))
        end

        def css_classes(extra = nil)
          super([
            "[&_svg:not([class*='size-'])]:size-4",
            "group-has-data-[slot=combobox-clear]/input-group:hidden data-pressed:bg-transparent",
            extra
          ].compact.join(" "))
        end

        def call
          render_element(body: render(Icon::Component.new("chevron-down", class: ICON_CLASSES,
                                                          "data-slot": "combobox-trigger-icon")))
        end
      end
    end
  end
end
