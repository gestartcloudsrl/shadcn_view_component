# frozen_string_literal: true

module Shadcn
  module Sidebar
    module Provider
      # SidebarProvider — the wrapper that holds the state for everything below
      # it. In React that state is a context (vendor/shadcn/ui/sidebar.tsx:56);
      # here it is the Stimulus controller, which is why this element and not
      # the panel carries `data-controller`.
      #
      # Upstream also wraps its children in a `TooltipProvider` with
      # `delayDuration={0}`, so a collapsed sidebar's icons can explain
      # themselves. This port has no provider component — each Tooltip carries
      # its own delay — so there is nothing to reproduce here.
      class Component < ApplicationViewComponent
        WIDTH = "16rem"
        WIDTH_ICON = "3rem"
        # Upstream's `SIDEBAR_WIDTH_MOBILE` (sidebar.tsx:31), which it applies by
        # overriding `--sidebar-width` on the Sheet it renders instead of the
        # panel. There is no second element here to override it on, so it is
        # published as its own variable and the panel reaches for it directly.
        WIDTH_MOBILE = "18rem"

        slot_name :"sidebar-wrapper"

        style do
          base { "group/sidebar-wrapper flex min-h-svh w-full has-data-[variant=inset]:bg-sidebar" }
        end

        attr_reader :open

        # `open:` is what a Rails layout passes after reading the
        # `sidebar_state` cookie, the way a Next.js layout passes `defaultOpen`.
        # It defaults to open, as upstream's does.
        def initialize(open: true, **attributes)
          @open = open
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{
            style: merged_style(
              "--sidebar-width: #{WIDTH}; --sidebar-width-icon: #{WIDTH_ICON}; " \
              "--sidebar-width-mobile: #{WIDTH_MOBILE};"
            ),
            "data-controller" => "shadcn--sidebar",
            "data-shadcn--sidebar-open-value" => open
          }.merge(defaults))
        end
      end
    end
  end
end
