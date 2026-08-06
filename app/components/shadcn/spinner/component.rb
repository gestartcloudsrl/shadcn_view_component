# frozen_string_literal: true

module Shadcn
  module Spinner
    # Port of registry/new-york-v4/ui/spinner.tsx — the lucide Loader2 icon
    # with a status role.
    class Component < Icon::Component
      def initialize(**attributes)
        super("loader-2", **attributes)
      end

      def element_attributes(**defaults)
        super(**{ role: "status", "aria-label" => shadcn_t("spinner.loading") }.merge(defaults))
      end

      def css_classes(extra = nil)
        super(ShadcnViewComponent.cn("size-4 animate-spin", extra))
      end
    end
  end
end
