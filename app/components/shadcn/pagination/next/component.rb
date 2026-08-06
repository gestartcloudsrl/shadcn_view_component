# frozen_string_literal: true

module Shadcn
  module Pagination
    module Next
      # PaginationNext
      class Component < Link::Component
        EXTRA_CLASSES = "gap-1 px-2.5 sm:pr-2.5"

        def initialize(**attributes)
          super(size: :default, **attributes)
        end

        def element_attributes(**defaults)
          super(**{ "aria-label" => shadcn_t("pagination.go_to_next") }.merge(defaults))
        end

        def css_classes(extra = nil)
          super(ShadcnViewComponent.cn(EXTRA_CLASSES, extra))
        end

        def call
          render_element(body: safe_join([
            tag.span(shadcn_t("pagination.next"), class: "hidden sm:block"),
            render(Icon::Component.new("chevron-right"))
          ]))
        end
      end
    end
  end
end
