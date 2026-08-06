# frozen_string_literal: true

module Shadcn
  module Dialog
    module Content
      # DialogContent — renders its own overlay, as the TSX does, and the
      # dismiss button in the corner unless asked not to.
      class Component < ApplicationViewComponent
        CLOSE_CLASSES = "absolute top-4 right-4 rounded-xs opacity-70 ring-offset-background " \
                        "transition-opacity hover:opacity-100 focus:ring-2 focus:ring-ring " \
                        "focus:ring-offset-2 focus:outline-hidden disabled:pointer-events-none " \
                        "data-[state=open]:bg-accent data-[state=open]:text-muted-foreground " \
                        "[&_svg]:pointer-events-none [&_svg]:shrink-0 " \
                        "[&_svg:not([class*='size-'])]:size-4"

        renders_one :header, "Shadcn::Dialog::Header::Component"
        renders_one :footer, "Shadcn::Dialog::Footer::Component"

        slot_name :"dialog-content"

        style do
          base {
            "fixed top-[50%] left-[50%] z-50 grid w-full max-w-[calc(100%-2rem)] " \
            "translate-x-[-50%] translate-y-[-50%] gap-4 rounded-lg border bg-background p-6 " \
            "shadow-lg duration-200 outline-none data-[state=closed]:animate-out " \
            "data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 " \
            "data-[state=open]:animate-in data-[state=open]:fade-in-0 " \
            "data-[state=open]:zoom-in-95 sm:max-w-lg"
          }
        end

        attr_reader :show_close_button

        def initialize(show_close_button: true, **attributes)
          @show_close_button = show_close_button
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{
            role: "dialog",
            "aria-modal" => "true",
            tabindex: "-1",
            "data-state" => "closed",
            hidden: true,
            "data-shadcn--dialog-target" => "content"
          }.merge(defaults))
        end

        # shadcn wraps the overlay and the content in a DialogPortal. Radix
        # relocates that element to `document.body`; here it stays put (see
        # the `shadcn--dialog` controller for why) and is `display: contents`,
        # so it adds no box of its own.
        def call
          tag.div("data-slot": "dialog-portal", style: CONTENTS_STYLE) do
            safe_join([
              render(Overlay::Component.new),
              render_element(body: safe_join([ header, content, footer, close_button ].compact))
            ])
          end
        end

        private

        def close_button
          return unless show_close_button

          render(Close::Component.new(class: CLOSE_CLASSES)) do
            safe_join([
              render(Icon::Component.new("x")),
              tag.span(shadcn_t("dialog.close"), class: "sr-only")
            ])
          end
        end
      end
    end
  end
end
