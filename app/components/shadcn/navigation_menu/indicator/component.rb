# frozen_string_literal: true

module Shadcn
  module NavigationMenu
    module Indicator
      # The little arrow that slides under whichever trigger is open. Its own
      # file for the rotated `div` inside it (navigation-menu.tsx:153), which
      # `part` does not do.
      #
      # Position and width are the controller's, as two custom properties —
      # Radix publishes the same pair.
      class Component < ApplicationViewComponent
        slot_name :"navigation-menu-indicator"

        style do
          base {
            "top-full z-[1] flex h-1.5 items-end justify-center overflow-hidden " \
            "data-[state=hidden]:animate-out data-[state=hidden]:fade-out " \
            "data-[state=visible]:animate-in data-[state=visible]:fade-in"
          }
        end

        def element_attributes(**defaults)
          super(**{
            hidden: true,
            "data-state" => "hidden",
            "aria-hidden" => "true",
            "data-shadcn--navigation-menu-target" => "indicator",
            style: merged_style(
              "position: absolute; left: 0; " \
              "width: var(--radix-navigation-menu-indicator-size, 0px); " \
              "transform: translateX(var(--radix-navigation-menu-indicator-position, 0px));"
            )
          }.merge(defaults))
        end

        def call
          render_element(
            body: tag.div(class: "relative top-[60%] h-2 w-2 rotate-45 rounded-tl-sm bg-border shadow-md")
          )
        end
      end
    end
  end
end
