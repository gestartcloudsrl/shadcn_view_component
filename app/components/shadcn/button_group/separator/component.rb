# frozen_string_literal: true

module Shadcn
  module ButtonGroup
    module Separator
      # ButtonGroupSeparator renders a Separator rather than a bare element, and
      # overrides three things about it: the `data-slot`, the default
      # orientation, and a handful of classes layered on top of the separator's
      # own — `cn(separatorClasses, …)` in the TSX.
      #
      # Borrowing the parent's compiled classes rather than restating them is
      # the same move `PaginationLink` makes with `Button`, and is why
      # `parity_spec` lists this family as inheriting from `separator`.
      class Component < Shadcn::Separator::Component
        slot_name :"button-group-separator"

        EXTRA_CLASSES = "relative m-0! self-stretch bg-input " \
                        "data-[orientation=vertical]:h-auto"

        def initialize(orientation: :vertical, **attributes)
          super(orientation:, **attributes)
        end

        def css_classes(extra = nil)
          super([ EXTRA_CLASSES, extra ].compact.join(" "))
        end
      end
    end
  end
end
