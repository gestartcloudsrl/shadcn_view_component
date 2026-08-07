# frozen_string_literal: true

module Shadcn
  module InputGroup
    # Port of registry/new-york-v4/ui/input-group.tsx
    #
    # `group/input-group` is a named Tailwind group the addon's classes reach
    # back into (`group-has-[>input]/input-group:…`), so the two halves only
    # work as a pair.
    class Component < ApplicationViewComponent
      slot_name :"input-group"

      style do
        base {
          "group/input-group relative flex w-full items-center rounded-md border " \
          "border-input shadow-xs transition-[color,box-shadow] outline-none " \
          "dark:bg-input/30 h-9 min-w-0 has-[>textarea]:h-auto " \
          "has-[>[data-align=inline-start]]:[&>input]:pl-2 " \
          "has-[>[data-align=inline-end]]:[&>input]:pr-2 " \
          "has-[>[data-align=block-start]]:h-auto " \
          "has-[>[data-align=block-start]]:flex-col " \
          "has-[>[data-align=block-start]]:[&>input]:pb-3 " \
          "has-[>[data-align=block-end]]:h-auto " \
          "has-[>[data-align=block-end]]:flex-col " \
          "has-[>[data-align=block-end]]:[&>input]:pt-3 " \
          "has-[[data-slot=input-group-control]:focus-visible]:border-ring " \
          "has-[[data-slot=input-group-control]:focus-visible]:ring-[3px] " \
          "has-[[data-slot=input-group-control]:focus-visible]:ring-ring/50 " \
          "has-[[data-slot][aria-invalid=true]]:border-destructive " \
          "has-[[data-slot][aria-invalid=true]]:ring-destructive/20 " \
          "dark:has-[[data-slot][aria-invalid=true]]:ring-destructive/40"
        }
      end

      # The controller lives on the group rather than on the addon, so that
      # `this.element` is the group and the lookup matches upstream's
      # `currentTarget.parentElement.querySelector("input")`.
      def element_attributes(**defaults)
        super(**{ role: "group", "data-controller" => "shadcn--input-group" }.merge(defaults))
      end
    end
  end
end
