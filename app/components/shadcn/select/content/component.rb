# frozen_string_literal: true

module Shadcn
  module Select
    module Content
      # SelectContent — the viewport and the two scroll buttons are part of the
      # markup shadcn emits, so they are reproduced here.
      class Component < ApplicationViewComponent
        SCROLL_BUTTON_CLASSES = "flex cursor-default items-center justify-center py-1"

        renders_many :items, "Shadcn::Select::Item::Component"

        slot_name :"select-content"

        style do
          base {
            "relative z-50 max-h-(--radix-select-content-available-height) min-w-[8rem] " \
            "origin-(--radix-select-content-transform-origin) overflow-x-hidden " \
            "overflow-y-auto rounded-md border bg-popover text-popover-foreground shadow-md " \
            "data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 " \
            "data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 " \
            "data-[state=closed]:animate-out data-[state=closed]:fade-out-0 " \
            "data-[state=closed]:zoom-out-95 data-[state=open]:animate-in " \
            "data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95"
          }

          variants {
            position {
              popper {
                "data-[side=bottom]:translate-y-1 data-[side=left]:-translate-x-1 " \
                "data-[side=right]:translate-x-1 data-[side=top]:-translate-y-1"
              }
              send(:"item-aligned") { "" }
            }
          }

          defaults { { position: :"item-aligned" } }
        end

        attr_reader :position

        def initialize(position: :"item-aligned", **attributes)
          @position = position&.to_sym || :"item-aligned"
          super(**attributes)
        end

        def style_variants
          { position: }
        end

        def element_attributes(**defaults)
          super(**{
            role: "listbox",
            tabindex: "-1",
            "data-state" => "closed",
            hidden: true,
            "data-shadcn--select-target" => "content",
            "data-action" => "keydown->shadcn--select#contentKeydown"
          }.merge(defaults))
        end

        def call
          render_element(body: safe_join([
            scroll_button("select-scroll-up-button", "chevron-up"),
            viewport,
            scroll_button("select-scroll-down-button", "chevron-down")
          ]))
        end

        private

        def viewport
          tag.div(safe_join([ items, content ].flatten.compact), class: viewport_classes)
        end

        def viewport_classes
          extra =
            if position == :popper
              "h-[var(--radix-select-trigger-height)] w-full " \
              "min-w-[var(--radix-select-trigger-width)] scroll-my-1"
            end

          ShadcnViewComponent.cn("p-1", extra)
        end

        def scroll_button(slot, icon)
          tag.div(
            render(Icon::Component.new(icon, class: "size-4")),
            "data-slot": slot,
            class: SCROLL_BUTTON_CLASSES
          )
        end
      end
    end
  end
end
