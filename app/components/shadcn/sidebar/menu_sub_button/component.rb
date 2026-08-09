# frozen_string_literal: true

module Shadcn
  module Sidebar
    module MenuSubButton
      # SidebarMenuSubButton — an `<a>` rather than a button, because a submenu
      # row is a link upstream (vendor/shadcn/ui/sidebar.tsx:680).
      class Component < ApplicationViewComponent
        default_tag :a
        slot_name :"sidebar-menu-sub-button"

        style do
          base {
            "flex h-7 min-w-0 -translate-x-px items-center gap-2 overflow-hidden " \
            "rounded-md px-2 text-sidebar-foreground ring-sidebar-ring " \
            "outline-hidden hover:bg-sidebar-accent " \
            "hover:text-sidebar-accent-foreground focus-visible:ring-2 " \
            "active:bg-sidebar-accent active:text-sidebar-accent-foreground " \
            "disabled:pointer-events-none disabled:opacity-50 " \
            "aria-disabled:pointer-events-none aria-disabled:opacity-50 " \
            "[&>span:last-child]:truncate [&>svg]:size-4 [&>svg]:shrink-0 " \
            "[&>svg]:text-sidebar-accent-foreground " \
            "data-[active=true]:bg-sidebar-accent " \
            "data-[active=true]:text-sidebar-accent-foreground sm md " \
            "group-data-[collapsible=icon]:hidden"
          }

          variants {
            size {
              sm { "text-xs" }
              md { "text-sm" }
            }
          }

          defaults { { size: :md } }
        end

        attr_reader :size, :active

        def initialize(size: :md, active: false, **attributes)
          @size = size&.to_sym || :md
          @active = active
          super(**attributes)
        end

        def style_variants
          { size: }
        end

        def element_attributes(**defaults)
          super(**{
            "data-sidebar" => "menu-sub-button",
            "data-size" => size,
            "data-active" => active.to_s
          }.merge(defaults))
        end
      end
    end
  end
end
