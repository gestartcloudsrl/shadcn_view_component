# frozen_string_literal: true

module Shadcn
  module Sidebar
    module MenuButton
      # SidebarMenuButton — the row a sidebar is mostly made of.
      #
      # `tooltip:` is not ported. Upstream wraps the button in a Tooltip whose
      # content is hidden unless the sidebar is collapsed and not on a phone
      # (vendor/shadcn/ui/sidebar.tsx:534-542) — runtime state a server cannot
      # know, and wiring it needs controller work this batch does not do. See
      # features/sidebar.md.
      class Component < ApplicationViewComponent
        default_tag :button
        slot_name :"sidebar-menu-button"

        style do
          base {
            "peer/menu-button flex w-full items-center gap-2 overflow-hidden " \
              "rounded-md p-2 text-left text-sm ring-sidebar-ring outline-hidden " \
              "transition-[width,height,padding] " \
              "group-has-data-[sidebar=menu-action]/menu-item:pr-8 " \
              "group-data-[collapsible=icon]:size-8! " \
              "group-data-[collapsible=icon]:p-2! hover:bg-sidebar-accent " \
              "hover:text-sidebar-accent-foreground focus-visible:ring-2 " \
              "active:bg-sidebar-accent active:text-sidebar-accent-foreground " \
              "disabled:pointer-events-none disabled:opacity-50 " \
              "aria-disabled:pointer-events-none aria-disabled:opacity-50 " \
              "data-[active=true]:bg-sidebar-accent data-[active=true]:font-medium " \
              "data-[active=true]:text-sidebar-accent-foreground " \
              "data-[state=open]:hover:bg-sidebar-accent " \
              "data-[state=open]:hover:text-sidebar-accent-foreground " \
              "[&>span:last-child]:truncate [&>svg]:size-4 [&>svg]:shrink-0"
          }

          variants {
            variant {
              default { "hover:bg-sidebar-accent hover:text-sidebar-accent-foreground" }
              outline {
                "bg-background shadow-[0_0_0_1px_var(--sidebar-border)] " \
                  "hover:bg-sidebar-accent hover:text-sidebar-accent-foreground " \
                  "hover:shadow-[0_0_0_1px_var(--sidebar-accent)]"
              }
            }

            size {
              default { "h-8 text-sm" }
              sm { "h-7 text-xs" }
              lg { "h-12 text-sm group-data-[collapsible=icon]:p-0!" }
            }
          }

          defaults { { variant: :default, size: :default } }
        end

        attr_reader :variant, :size, :active

        def initialize(variant: :default, size: :default, active: false, **attributes)
          @variant = variant&.to_sym || :default
          @size = size&.to_sym || :default
          @active = active
          super(**attributes)
        end

        def style_variants
          { variant:, size: }
        end

        def element_attributes(**defaults)
          super(**{
            type: "button",
            "data-sidebar" => "menu-button",
            "data-size" => size,
            "data-active" => active.to_s
          }.merge(defaults))
        end
      end
    end
  end
end
