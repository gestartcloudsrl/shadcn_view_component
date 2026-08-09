# frozen_string_literal: true

module Shadcn
  # The parts of the NavigationMenu family that are an element with a
  # `data-slot` and a fixed set of classes.
  module NavigationMenu
    extend Parts

    part :list, slot: "navigation-menu-list", tag: :ul,
                classes: "group flex flex-1 list-none items-center justify-center gap-1"

    part :item, slot: "navigation-menu-item", tag: :li, classes: "relative"

    # The rows inside a panel. `data-active` is the caller's — this is a nav, so
    # which link is current is the application's business, not the menu's.
    part :link, slot: "navigation-menu-link",
                classes: "flex flex-col gap-1 rounded-sm p-2 text-sm transition-all " \
                         "outline-none hover:bg-accent hover:text-accent-foreground " \
                         "focus:bg-accent focus:text-accent-foreground " \
                         "focus-visible:ring-[3px] focus-visible:ring-ring/50 " \
                         "focus-visible:outline-1 data-[active=true]:bg-accent/50 " \
                         "data-[active=true]:text-accent-foreground " \
                         "data-[active=true]:hover:bg-accent " \
                         "data-[active=true]:focus:bg-accent " \
                         "[&_svg:not([class*='size-'])]:size-4 " \
                         "[&_svg:not([class*='text-'])]:text-muted-foreground"
  end
end
