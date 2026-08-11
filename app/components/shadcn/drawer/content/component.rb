# frozen_string_literal: true

module Shadcn
  module Drawer
    module Content
      # DrawerContent — renders its own overlay, as the TSX does, and the drag
      # handle above the content.
      #
      # Unlike the Sheet, the four edges are *not* cva variants: upstream emits
      # all four sets of classes at once and lets `data-vaul-drawer-direction`
      # pick between them, so this element carries every one of them and the
      # attribute does the choosing. That attribute name is vaul's, not ours —
      # it is in the class strings this port has to reproduce byte for byte, so
      # the markup has to speak it.
      class Component < ApplicationViewComponent
        DIRECTIONS = %i[top bottom left right].freeze

        HANDLE_CLASSES = "mx-auto mt-4 hidden h-2 w-[100px] shrink-0 rounded-full bg-muted " \
                         "group-data-[vaul-drawer-direction=bottom]/drawer-content:block"

        renders_one :header, "Shadcn::Drawer::Header::Component"
        renders_one :footer, "Shadcn::Drawer::Footer::Component"

        slot_name :"drawer-content"

        style do
          base {
            "group/drawer-content fixed z-50 flex h-auto flex-col bg-background " \
            "data-[vaul-drawer-direction=top]:inset-x-0 data-[vaul-drawer-direction=top]:top-0 " \
            "data-[vaul-drawer-direction=top]:mb-24 data-[vaul-drawer-direction=top]:max-h-[80vh] " \
            "data-[vaul-drawer-direction=top]:rounded-b-lg data-[vaul-drawer-direction=top]:border-b " \
            "data-[vaul-drawer-direction=bottom]:inset-x-0 data-[vaul-drawer-direction=bottom]:bottom-0 " \
            "data-[vaul-drawer-direction=bottom]:mt-24 data-[vaul-drawer-direction=bottom]:max-h-[80vh] " \
            "data-[vaul-drawer-direction=bottom]:rounded-t-lg data-[vaul-drawer-direction=bottom]:border-t " \
            "data-[vaul-drawer-direction=right]:inset-y-0 data-[vaul-drawer-direction=right]:right-0 " \
            "data-[vaul-drawer-direction=right]:w-3/4 data-[vaul-drawer-direction=right]:border-l " \
            "data-[vaul-drawer-direction=right]:sm:max-w-sm " \
            "data-[vaul-drawer-direction=left]:inset-y-0 data-[vaul-drawer-direction=left]:left-0 " \
            "data-[vaul-drawer-direction=left]:w-3/4 data-[vaul-drawer-direction=left]:border-r " \
            "data-[vaul-drawer-direction=left]:sm:max-w-sm"
          }
        end

        attr_reader :direction

        def initialize(direction: :bottom, **attributes)
          @direction = DIRECTIONS.include?(direction&.to_sym) ? direction.to_sym : :bottom
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{
            role: "dialog",
            "aria-modal" => "true",
            tabindex: "-1",
            "data-state" => "closed",
            hidden: true,
            "data-vaul-drawer" => "",
            "data-vaul-drawer-direction" => direction,
            # A constant, because this port has no snap points — and named
            # rather than dropped because vaul's own selectors carry it, and the
            # stylesheet reproduced in `shadcn.css` matches on it.
            "data-vaul-snap-points" => "false",
            "data-shadcn--dialog-target" => "content",
            "data-shadcn--drawer-target" => "content",
            "data-action" => "pointerdown->shadcn--drawer#press " \
                             "pointermove->shadcn--drawer#move " \
                             "pointerup->shadcn--drawer#release " \
                             "pointercancel->shadcn--drawer#release"
          }.merge(defaults))
        end

        # shadcn wraps the overlay and the content in a DrawerPortal, which vaul
        # relocates to `document.body`; here it stays put, as the dialog's does,
        # and is `display: contents` so it adds no box of its own.
        def call
          tag.div("data-slot": "drawer-portal", style: CONTENTS_STYLE) do
            safe_join([
              render(Overlay::Component.new("data-vaul-overlay": "", "data-shadcn--drawer-target": "overlay")),
              render_element(body: safe_join([ handle, header, content, footer ].compact))
            ])
          end
        end

        private

        # Shown only when the drawer comes up from the bottom — the class does
        # that, so it is rendered whatever the direction, exactly as upstream.
        def handle
          tag.div(class: HANDLE_CLASSES)
        end
      end
    end
  end
end
