# frozen_string_literal: true

module Shadcn
  module Item
    module Group
      # ItemGroup. Only a `data-slot` and classes apart from `role="list"`,
      # which is why it is not a `part` — the macro declares no attributes.
      #
      # **`role="list"` obliges its children to be `role="listitem"`, and `Item`
      # carries no role.** So a group whose items are left bare fails axe's
      # `aria-required-children` as soon as one of them contains a button or a
      # link — which is most of them. shadcn has the same gap; the markup is
      # kept 1:1 and the preview shows the working spelling
      # (`Item::Component.new(role: "listitem")`), the way the FormBuilder
      # demonstrates the accessible name that Select and Switch cannot supply
      # themselves. See [todo](../../../../../.claude/docs/todo.md).
      class Component < ApplicationViewComponent
        slot_name :"item-group"

        style do
          base { "group/item-group flex flex-col" }
        end

        def element_attributes(**defaults)
          super(**{ role: "list" }.merge(defaults))
        end
      end
    end
  end
end
