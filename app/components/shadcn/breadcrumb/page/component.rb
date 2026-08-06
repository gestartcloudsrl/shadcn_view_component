# frozen_string_literal: true

module Shadcn
  module Breadcrumb
    module Page
      # BreadcrumbPage — the current, non-navigable crumb.
      class Component < ApplicationViewComponent
        default_tag :span
        slot_name :"breadcrumb-page"

        style do
          base { "font-normal text-foreground" }
        end

        def element_attributes(**defaults)
          super(**{
            role: "link",
            "aria-disabled" => "true",
            "aria-current" => "page"
          }.merge(defaults))
        end
      end
    end
  end
end
