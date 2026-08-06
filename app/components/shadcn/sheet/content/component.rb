# frozen_string_literal: true

module Shadcn
  module Sheet
    module Content
      # SheetContent — slides in from one of the four edges.
      class Component < ApplicationViewComponent
        CLOSE_CLASSES = "absolute top-4 right-4 rounded-xs opacity-70 ring-offset-background " \
                        "transition-opacity hover:opacity-100 focus:ring-2 focus:ring-ring " \
                        "focus:ring-offset-2 focus:outline-hidden disabled:pointer-events-none " \
                        "data-[state=open]:bg-secondary"

        renders_one :header, "Shadcn::Sheet::Header::Component"
        renders_one :footer, "Shadcn::Sheet::Footer::Component"

        slot_name :"sheet-content"

        style do
          base {
            "fixed z-50 flex flex-col gap-4 bg-background shadow-lg transition ease-in-out " \
            "data-[state=closed]:animate-out data-[state=closed]:duration-300 " \
            "data-[state=open]:animate-in data-[state=open]:duration-500"
          }

          variants {
            side {
              right {
                "inset-y-0 right-0 h-full w-3/4 border-l " \
                "data-[state=closed]:slide-out-to-right " \
                "data-[state=open]:slide-in-from-right sm:max-w-sm"
              }
              left {
                "inset-y-0 left-0 h-full w-3/4 border-r " \
                "data-[state=closed]:slide-out-to-left " \
                "data-[state=open]:slide-in-from-left sm:max-w-sm"
              }
              top {
                "inset-x-0 top-0 h-auto border-b data-[state=closed]:slide-out-to-top " \
                "data-[state=open]:slide-in-from-top"
              }
              bottom {
                "inset-x-0 bottom-0 h-auto border-t data-[state=closed]:slide-out-to-bottom " \
                "data-[state=open]:slide-in-from-bottom"
              }
            }
          }

          defaults { { side: :right } }
        end

        attr_reader :side, :show_close_button

        def initialize(side: :right, show_close_button: true, **attributes)
          @side = side&.to_sym || :right
          @show_close_button = show_close_button
          super(**attributes)
        end

        def style_variants
          { side: }
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

        def call
          tag.div("data-slot": "sheet-portal", style: CONTENTS_STYLE) do
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
              render(Icon::Component.new("x", class: "size-4")),
              tag.span(shadcn_t("dialog.close"), class: "sr-only")
            ])
          end
        end
      end
    end
  end
end
