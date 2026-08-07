# frozen_string_literal: true

module Shadcn
  module ButtonGroup
    module Text
      # ButtonGroupText. Deliberately has no `data-slot`: upstream emits none,
      # so `slot_name` is never called and `element_attributes` drops the key.
      #
      # Its `asChild` is the base class's `as:`, which needs no code here.
      class Component < ApplicationViewComponent
        style do
          base {
            "flex items-center gap-2 rounded-md border bg-muted px-4 text-sm font-medium " \
            "shadow-xs [&_svg]:pointer-events-none [&_svg:not([class*='size-'])]:size-4"
          }
        end
      end
    end
  end
end
