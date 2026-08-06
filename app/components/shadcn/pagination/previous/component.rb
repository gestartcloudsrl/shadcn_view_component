# frozen_string_literal: true

module Shadcn
  module Pagination
    module Previous
      # PaginationPrevious
      class Component < Link::Component
        EXTRA_CLASSES = "gap-1 px-2.5 sm:pl-2.5"

        def initialize(**attributes)
          super(size: :default, **attributes)
        end

        def element_attributes(**defaults)
          super(**{ "aria-label" => shadcn_t("pagination.go_to_previous") }.merge(defaults))
        end

        def css_classes(extra = nil)
          super(ShadcnViewComponent.cn(EXTRA_CLASSES, extra))
        end

        def call
          render_element(body: safe_join([
            render(Icon::Component.new("chevron-left")),
            tag.span(shadcn_t("pagination.previous"), class: "hidden sm:block")
          ]))
        end
      end
    end
  end
end
