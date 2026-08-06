# frozen_string_literal: true

module Shadcn
  module Breadcrumb
    # Port of registry/new-york-v4/ui/breadcrumb.tsx
    class Component < ApplicationViewComponent
      default_tag :nav
      slot_name :breadcrumb

      def element_attributes(**defaults)
        super(**{ "aria-label" => shadcn_t("breadcrumb.label") }.merge(defaults))
      end
    end
  end
end
