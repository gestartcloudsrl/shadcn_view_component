# frozen_string_literal: true

module Shadcn
  module Textarea
    # Port of registry/new-york-v4/ui/textarea.tsx
    class Component < ApplicationViewComponent
      default_tag :textarea
      slot_name :textarea

      style do
        base {
          "flex field-sizing-content min-h-16 w-full rounded-md border border-input " \
          "bg-transparent px-3 py-2 text-base shadow-xs " \
          "transition-[color,box-shadow] outline-none " \
          "placeholder:text-muted-foreground focus-visible:border-ring " \
          "focus-visible:ring-[3px] focus-visible:ring-ring/50 " \
          "disabled:cursor-not-allowed disabled:opacity-50 " \
          "aria-invalid:border-destructive aria-invalid:ring-destructive/20 " \
          "md:text-sm dark:bg-input/30 dark:aria-invalid:ring-destructive/40"
        }
      end
    end
  end
end
