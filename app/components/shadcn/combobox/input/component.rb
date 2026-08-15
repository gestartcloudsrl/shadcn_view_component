# frozen_string_literal: true

module Shadcn
  module Combobox
    module Input
      # The field, inside an InputGroup with the chevron and — when asked for —
      # the clear button in its trailing addon. Upstream composes exactly these
      # three, and all three are ported here already.
      class Component < ApplicationViewComponent
        # No `data-slot` of its own: upstream renders
        # `<ComboboxPrimitive.Input render={<InputGroupInput/>}/>`, so the field
        # a person types into carries `input-group-control`. Read from the
        # rendered example — `combobox-input` was invented here and does not
        # exist upstream.
        default_tag :input
        slot_name :"input-group-control"

        attr_reader :show_trigger, :show_clear, :disabled, :placeholder, :value

        def initialize(show_trigger: true, show_clear: false, disabled: false,
                       placeholder: nil, value: nil, **attributes)
          @show_trigger = show_trigger
          @show_clear = show_clear
          @disabled = disabled
          @placeholder = placeholder
          @value = value
          super(**attributes)
        end

        # Base UI's combobox input is a `role="combobox"` with the list under
        # `aria-controls`, and the panel's open state on `aria-expanded` — the
        # same contract Radix's select trigger has, which is why the controller
        # can wire both the same way.
        def element_attributes(**defaults)
          super(**{
            type: "text",
            value:,
            placeholder:,
            disabled: disabled.presence,
            role: "combobox",
            autocomplete: "off",
            autocapitalize: "none",
            autocorrect: "off",
            spellcheck: "false",
            "aria-autocomplete" => "list",
            "aria-haspopup" => "listbox",
            "aria-expanded" => "false",
            "data-shadcn--combobox-target" => "search",
            # `click`, not `focus`: taking an option puts the caret back in the
            # field, and on `focus` that reopened the panel the choice had just
            # closed. A pointer opens it by clicking, a keyboard by pressing
            # Down — which is what both do anyway.
            "data-action" => "input->shadcn--combobox#search click->shadcn--combobox#open " \
                             "keydown->shadcn--combobox#keydown"
          }.compact.merge(defaults))
        end

        def call
          render(Shadcn::InputGroup::Component.new(class: "w-auto")) do
            safe_join([ field, addon ].compact)
          end
        end

        private

        # The input itself is an `InputGroupInput`, which is upstream's `render`
        # prop — a subclass here, the gem's mapping for `asChild`.
        def field
          render(Shadcn::InputGroup::Input::Component.new(**element_attributes))
        end

        def addon
          return if !show_trigger && !show_clear

          render(Shadcn::InputGroup::Addon::Component.new(align: :"inline-end")) do
            safe_join([
              (render(Trigger::Component.new(disabled:)) if show_trigger),
              (render(Clear::Component.new(disabled:)) if show_clear)
            ].compact)
          end
        end
      end
    end
  end
end
