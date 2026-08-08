# frozen_string_literal: true

module Shadcn
  module Select
    module Empty
      # Shown when the filter matches nothing.
      #
      # A *sibling* of the listbox rather than a child of it. shadcn's aria
      # variant nests its empty state inside the list and gives it
      # `role="option"` — an option that cannot be chosen — which is how React
      # Aria's collection renders one. Outside the list the question does not
      # arise, and a non-option inside a listbox is precisely the shape axe
      # rejected while this component's structure was being chosen.
      #
      # The classes are this gem's own. Upstream's are a single
      # `cn-select-empty-aria`, defined across the themed sheets in
      # `registry/styles/`, which this gem does not ship.
      class Component < ApplicationViewComponent
        slot_name :"select-empty"

        style do
          base { "py-6 text-center text-sm text-muted-foreground" }
        end

        def element_attributes(**defaults)
          super(**{
            hidden: true,
            "data-shadcn--select-target" => "empty"
          }.merge(defaults))
        end

        def call
          render_element(body: content.presence || shadcn_t("select.empty"))
        end
      end
    end
  end
end
