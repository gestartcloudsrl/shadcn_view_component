# frozen_string_literal: true

module Shadcn
  module Item
    module Separator
      # ItemSeparator renders a Separator with its own `data-slot` and one class
      # on top, the way ButtonGroupSeparator does. Upstream pins the orientation
      # to horizontal rather than defaulting it, so it is not a keyword here.
      class Component < Shadcn::Separator::Component
        slot_name :"item-separator"

        EXTRA_CLASSES = "my-0"

        def initialize(**attributes)
          super(orientation: :horizontal, **attributes)
        end

        def css_classes(extra = nil)
          super([ EXTRA_CLASSES, extra ].compact.join(" "))
        end
      end
    end
  end
end
