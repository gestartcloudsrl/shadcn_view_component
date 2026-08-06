# frozen_string_literal: true

module Shadcn
  module Pagination
    module Link
      # PaginationLink — styled with the button's own variants, like the TSX
      # does via `buttonVariants({ variant: isActive ? "outline" : "ghost", size })`.
      class Component < ApplicationViewComponent
        default_tag :a
        slot_name :"pagination-link"

        attr_reader :active, :size

        def initialize(active: false, size: :icon, **attributes)
          @active = active
          @size = size&.to_sym || :icon
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{
            "aria-current" => ("page" if active),
            "data-active" => active
          }.merge(defaults))
        end

        def css_classes(extra = nil)
          Button::Component.variant_classes(
            variant: active ? :outline : :ghost,
            size:,
            class: extra
          )
        end
      end
    end
  end
end
