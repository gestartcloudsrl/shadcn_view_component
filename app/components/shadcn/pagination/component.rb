# frozen_string_literal: true

module Shadcn
  module Pagination
    # Port of registry/new-york-v4/ui/pagination.tsx
    class Component < ApplicationViewComponent
      default_tag :nav
      slot_name :pagination

      style do
        base { "mx-auto flex w-full justify-center" }
      end

      def element_attributes(**defaults)
        super(**{ role: "navigation", "aria-label" => shadcn_t("pagination.label") }.merge(defaults))
      end
    end
  end
end
