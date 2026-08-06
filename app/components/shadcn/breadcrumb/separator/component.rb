# frozen_string_literal: true

module Shadcn
  module Breadcrumb
    module Separator
      # BreadcrumbSeparator — falls back to a chevron when given no content.
      class Component < ApplicationViewComponent
        default_tag :li
        slot_name :"breadcrumb-separator"

        style do
          base { "[&>svg]:size-3.5" }
        end

        def element_attributes(**defaults)
          super(**{ role: "presentation", "aria-hidden" => "true" }.merge(defaults))
        end

        def call
          render_element(body: content.presence || default_separator)
        end

        private

        def default_separator
          render(Icon::Component.new("chevron-right"))
        end
      end
    end
  end
end
