# frozen_string_literal: true

module Shadcn
  module Separator
    # Port of registry/new-york-v4/ui/separator.tsx
    #
    # Reproduces Radix's semantics: a decorative separator is `role="none"`,
    # a meaningful one is `role="separator"` and only advertises
    # `aria-orientation` when vertical.
    class Component < ApplicationViewComponent
      slot_name :separator

      style do
        base {
          "shrink-0 bg-border data-[orientation=horizontal]:h-px " \
          "data-[orientation=horizontal]:w-full data-[orientation=vertical]:h-full " \
          "data-[orientation=vertical]:w-px"
        }
      end

      attr_reader :orientation, :decorative

      def initialize(orientation: :horizontal, decorative: true, **attributes)
        @orientation = orientation.to_sym
        @decorative = decorative
        super(**attributes)
      end

      def element_attributes(**defaults)
        semantics =
          if decorative
            { role: "none" }
          else
            { role: "separator", "aria-orientation" => (orientation.to_s if orientation == :vertical) }
          end

        super(**{ "data-orientation" => orientation }.merge(semantics).merge(defaults))
      end
    end
  end
end
