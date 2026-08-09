# frozen_string_literal: true

module Shadcn
  module Sidebar
    module MenuButton
      # SidebarMenuButton — the row a sidebar is mostly made of.
      #
      # `tooltip:` wraps the button in a Tooltip, as upstream does
      # (vendor/shadcn/ui/sidebar.tsx:534-542). Upstream decides whether to show
      # it with a runtime prop — `hidden={state !== "collapsed" || isMobile}` —
      # which a server cannot evaluate. Here the same two conditions are CSS,
      # read off the panel's own `group`: `data-state` is what the controller
      # already writes, and `data-mobile` is what it sets while the mobile sheet
      # is open. Same result, decided by the browser rather than by the render.
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

        # A tooltip is only of use when the label beside the icon is gone, so it
        # is hidden while the sidebar is expanded, and while the mobile sheet is
        # showing the full labels anyway.
        TOOLTIP_CLASSES = "group-data-[state=expanded]:hidden group-data-[mobile=true]:hidden"

        attr_reader :variant, :size, :active, :tooltip

        def initialize(variant: :default, size: :default, active: false, tooltip: nil, **attributes)
          @variant = variant&.to_sym || :default
          @size = size&.to_sym || :default
          @active = active
          @tooltip = tooltip
          super(**attributes)
        end

        def call
          return render_element(body: content) if tooltip.blank?

          render(Shadcn::Tooltip::Component.new(side: :right, align: :center)) do |wrapper|
            # The trigger takes this button's own attributes, `data-slot`
            # included, so the element in the document is still a
            # `sidebar-menu-button` — which is what upstream's `asChild` does.
            wrapper.with_trigger(as: tag_name, **element_attributes.transform_keys(&:to_sym)) { content }
            wrapper.with_tooltip_content(class: TOOLTIP_CLASSES) { tooltip }
          end
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
