# frozen_string_literal: true

module Shadcn
  module Kbd
    # Port of registry/new-york-v4/ui/kbd.tsx
    class Component < ApplicationViewComponent
      default_tag :kbd
      slot_name :kbd

      style do
        base {
          "pointer-events-none inline-flex h-5 w-fit min-w-5 items-center justify-center " \
          "gap-1 rounded-sm bg-muted px-1 font-sans text-xs font-medium " \
          "text-muted-foreground select-none " \
          "[&_svg:not([class*='size-'])]:size-3 " \
          "[[data-slot=tooltip-content]_&]:bg-background/20 " \
          "[[data-slot=tooltip-content]_&]:text-background " \
          "dark:[[data-slot=tooltip-content]_&]:bg-background/10"
        }
      end
    end
  end
end
