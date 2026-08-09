# frozen_string_literal: true

module Shadcn
  module Sidebar
    module MenuAction
      # SidebarMenuAction — the small button that sits on a menu item. It has a
      # variant, which is why it is a component rather than a `sidebar_part`.
      class Component < ApplicationViewComponent
        default_tag :button
        slot_name :"sidebar-menu-action"

        style do
          base {
            "absolute top-1.5 right-1 flex aspect-square w-5 items-center " \
            "justify-center rounded-md p-0 text-sidebar-foreground " \
            "ring-sidebar-ring outline-hidden transition-transform " \
            "peer-hover/menu-button:text-sidebar-accent-foreground " \
            "hover:bg-sidebar-accent hover:text-sidebar-accent-foreground " \
            "focus-visible:ring-2 [&>svg]:size-4 [&>svg]:shrink-0 after:absolute " \
            "after:-inset-2 md:after:hidden peer-data-[size=sm]/menu-button:top-1 " \
            "peer-data-[size=default]/menu-button:top-1.5 " \
            "peer-data-[size=lg]/menu-button:top-2.5 " \
            "group-data-[collapsible=icon]:hidden"
          }

          variants {
            show_on_hover {
              yes {
                "group-focus-within/menu-item:opacity-100 " \
                  "group-hover/menu-item:opacity-100 " \
                  "peer-data-[active=true]/menu-button:text-sidebar-accent-foreground " \
                  "data-[state=open]:opacity-100 md:opacity-0"
              }
              no { "" }
            }
          }

          defaults { { show_on_hover: :no } }
        end

        attr_reader :show_on_hover

        def initialize(show_on_hover: false, **attributes)
          @show_on_hover = show_on_hover
          super(**attributes)
        end

        def style_variants
          { show_on_hover: show_on_hover ? :yes : :no }
        end

        def element_attributes(**defaults)
          super(**{ type: "button", "data-sidebar" => "menu-action" }.merge(defaults))
        end
      end
    end
  end
end
