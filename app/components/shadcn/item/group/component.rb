# frozen_string_literal: true

module Shadcn
  module Item
    module Group
      # ItemGroup. Only a `data-slot` and classes apart from `role="list"`,
      # which is why it is not a `part` — the macro declares no attributes.
      #
      # **`role="list"` obliges its children to be `role="listitem"`, and `Item`
      # carries no role.** Adding one to `Item` itself would deviate from
      # upstream's markup, so it is added here instead, through the `items`
      # slot — the same layer the FormBuilder uses to supply the accessible
      # name that Select and Switch cannot give themselves. A bare
      # `Item::Component`, rendered outside this slot, still carries no role,
      # exactly as upstream has it.
      #
      # `ItemSeparator` goes through the same slot rather than the block:
      # `items` renders before block content (see `Card::Component`), so a
      # separator placed as plain block content between two `with_item` calls
      # would land after both of them instead of between them — the trap
      # CLAUDE.md warns about. A polymorphic slot keeps both in the one
      # ordered collection, where call order is preserved, and gives the
      # separator its own setter (`with_separator`) rather than a flag that
      # would otherwise let `Item` attributes reach a `role="none"` element.
      class Component < ApplicationViewComponent
        renders_many :items, types: {
          item: {
            renders: ->(**attributes) { Shadcn::Item::Component.new(role: "listitem", **attributes) },
            as: :item
          },
          separator: {
            renders: ->(**attributes) { Shadcn::Item::Separator::Component.new(**attributes) },
            as: :separator
          }
        }

        slot_name :"item-group"

        style do
          base { "group/item-group flex flex-col" }
        end

        def element_attributes(**defaults)
          super(**{ role: "list" }.merge(defaults))
        end

        def call
          render_element(body: safe_join([ *items, content ].compact))
        end
      end
    end
  end
end
