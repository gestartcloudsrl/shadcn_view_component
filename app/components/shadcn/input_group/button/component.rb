# frozen_string_literal: true

module Shadcn
  module InputGroup
    module Button
      # InputGroupButton renders a Button with its own size scale layered on
      # top, and forces three of the button's props.
      #
      # Those three are *defaults*, not overrides: they go through `super`, so
      # a caller asking for `variant: :destructive` still gets it. Ranking them
      # above the caller would make the button un-restylable.
      class Component < Shadcn::Button::Component
        SIZES = {
          xs: "h-6 gap-1 rounded-[calc(var(--radius)-5px)] px-2 has-[>svg]:px-2 " \
              "[&>svg:not([class*='size-'])]:size-3.5",
          sm: "h-8 gap-1.5 rounded-md px-2.5 has-[>svg]:px-2.5",
          "icon-xs": "size-6 rounded-[calc(var(--radius)-5px)] p-0 has-[>svg]:p-0",
          "icon-sm": "size-8 p-0 has-[>svg]:p-0"
        }.freeze

        attr_reader :group_size

        def initialize(variant: :ghost, size: :xs, **attributes)
          @group_size = size&.to_sym || :xs
          # The button's own size scale is not this one, so it keeps its
          # default; the group's scale is applied as classes instead.
          super(variant:, **attributes)
        end

        def element_attributes(**defaults)
          super(**{ type: "button", "data-size" => group_size }.merge(defaults))
        end

        def css_classes(extra = nil)
          super([ SIZES.fetch(group_size), extra ].compact.join(" "))
        end
      end
    end
  end
end
