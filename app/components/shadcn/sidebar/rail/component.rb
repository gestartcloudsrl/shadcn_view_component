# frozen_string_literal: true

module Shadcn
  module Sidebar
    module Rail
      # SidebarRail — the thin strip along the panel's edge that toggles it, and
      # shows a resize cursor while doing so. `tabindex="-1"` is upstream's:
      # the rail duplicates the trigger, so it is deliberately out of the tab
      # order (vendor/shadcn/ui/sidebar.tsx:282-305).
      class Component < ApplicationViewComponent
        default_tag :button
        slot_name :"sidebar-rail"

        style do
          base {
            "absolute inset-y-0 z-20 hidden w-4 -translate-x-1/2 transition-all ease-linear " \
            "group-data-[side=left]:-right-4 group-data-[side=right]:left-0 after:absolute " \
            "after:inset-y-0 after:left-1/2 after:w-[2px] hover:after:bg-sidebar-border sm:flex " \
            "in-data-[side=left]:cursor-w-resize in-data-[side=right]:cursor-e-resize " \
            "[[data-side=left][data-state=collapsed]_&]:cursor-e-resize " \
            "[[data-side=right][data-state=collapsed]_&]:cursor-w-resize " \
            "group-data-[collapsible=offcanvas]:translate-x-0 " \
            "group-data-[collapsible=offcanvas]:after:left-full " \
            "hover:group-data-[collapsible=offcanvas]:bg-sidebar " \
            "[[data-side=left][data-collapsible=offcanvas]_&]:-right-2 " \
            "[[data-side=right][data-collapsible=offcanvas]_&]:-left-2"
          }
        end

        def element_attributes(**defaults)
          super(**{
            type: "button",
            "data-sidebar" => "rail",
            "aria-label" => shadcn_t("sidebar.toggle"),
            "tabindex" => "-1",
            title: shadcn_t("sidebar.toggle"),
            "data-action" => "click->shadcn--sidebar#toggle"
          }.merge(defaults))
        end
      end
    end
  end
end
