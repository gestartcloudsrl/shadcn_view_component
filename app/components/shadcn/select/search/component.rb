# frozen_string_literal: true

module Shadcn
  module Select
    module Search
      # The filter field, composing the already-ported InputGroup the way
      # shadcn's aria variant does — its popover renders `data-slot="input-group"`
      # around the control, with the magnifier as an addon.
      #
      # Two things it does *not* copy from that variant, both with reasons in
      # decisions/01-architecture.md: the control keeps `input-group-control`
      # rather than being restamped `select-input`, because this port's group
      # raises its focus ring off that slot name and the aria one does not use
      # `has-[[data-slot=…]]` selectors at all; and the field carries an
      # accessible name, where upstream's has none — axe calls an unnamed one a
      # critical `label` violation.
      class Component < ApplicationViewComponent
        slot_name :"select-input-wrapper"

        style do
          base { "p-1 pb-0" }
        end

        attr_reader :label

        def initialize(label: nil, **attributes)
          @label = label
          super(**attributes)
        end

        def call
          render_element(body: render(InputGroup::Component.new) { safe_join([ field, addon ]) })
        end

        private

        def field
          render(InputGroup::Input::Component.new(
                   "aria-label": label || shadcn_t("select.search_label"),
                   "aria-autocomplete": "list",
                   "data-shadcn--select-target": "search",
                   "data-action": "input->shadcn--select#search"
                 ))
        end

        def addon
          render(InputGroup::Addon::Component.new) do
            render(Icon::Component.new("search", class: "size-4"))
          end
        end
      end
    end
  end
end
