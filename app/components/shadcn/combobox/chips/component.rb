# frozen_string_literal: true

module Shadcn
  module Combobox
    module Chips
      # The box that holds the chosen values as removable tokens, with the
      # field beside them — upstream's multiple-selection shape.
      #
      # It is the field's own frame here rather than an InputGroup: upstream's
      # classes draw the border, the ring and the invalid states themselves,
      # because the box grows with its chips where an InputGroup does not.
      class Component < ApplicationViewComponent
        default_tag :div
        slot_name :"combobox-chips"

        style do
          base {
            "flex min-h-9 flex-wrap items-center gap-1.5 rounded-md border border-input bg-transparent " \
            "bg-clip-padding px-2.5 py-1.5 text-sm shadow-xs transition-[color,box-shadow] " \
            "focus-within:border-ring focus-within:ring-[3px] focus-within:ring-ring/50 " \
            "has-aria-invalid:border-destructive has-aria-invalid:ring-[3px] " \
            "has-aria-invalid:ring-destructive/20 has-data-[slot=combobox-chip]:px-1.5 " \
            "dark:bg-input/30 dark:has-aria-invalid:border-destructive/50 " \
            "dark:has-aria-invalid:ring-destructive/40"
          }
        end
      end
    end
  end
end
