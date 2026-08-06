# frozen_string_literal: true

module Shadcn
  module Breadcrumb
    module Ellipsis
      # BreadcrumbEllipsis — collapsed crumbs.
      class Component < ApplicationViewComponent
        default_tag :span
        slot_name :"breadcrumb-ellipsis"

        style do
          base { "flex size-9 items-center justify-center" }
        end

        def element_attributes(**defaults)
          super(**{ role: "presentation", "aria-hidden" => "true" }.merge(defaults))
        end

        def call
          render_element(body: safe_join([
            render(Icon::Component.new("more-horizontal", class: "size-4")),
            tag.span(shadcn_t("breadcrumb.more"), class: "sr-only")
          ]))
        end
      end
    end
  end
end
