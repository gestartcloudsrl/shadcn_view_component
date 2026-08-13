# frozen_string_literal: true

module Shadcn
  module Resizable
    module Handle
      # The bar between two panels: a `role="separator"` that can be dragged and
      # driven from the keyboard.
      #
      # Its own orientation is the *opposite* of the group's — a row of panels
      # is divided by a vertical line — and `role="separator"` defaults to
      # horizontal, so the attribute is always written rather than left out.
      class Component < ApplicationViewComponent
        GRIP_CLASSES = "z-10 flex h-4 w-3 items-center justify-center rounded-xs border bg-border"

        default_tag :div
        slot_name :"resizable-handle"

        style do
          base {
            "relative flex w-px items-center justify-center bg-border after:absolute after:inset-y-0 " \
            "after:left-1/2 after:w-1 after:-translate-x-1/2 focus-visible:ring-1 focus-visible:ring-ring " \
            "focus-visible:ring-offset-1 focus-visible:outline-hidden aria-[orientation=horizontal]:h-px " \
            "aria-[orientation=horizontal]:w-full aria-[orientation=horizontal]:after:left-0 " \
            "aria-[orientation=horizontal]:after:h-1 aria-[orientation=horizontal]:after:w-full " \
            "aria-[orientation=horizontal]:after:translate-x-0 " \
            "aria-[orientation=horizontal]:after:-translate-y-1/2 " \
            "[&[aria-orientation=horizontal]>div]:rotate-90"
          }
        end

        attr_reader :with_handle, :orientation, :disabled

        # `with_handle:` is upstream's `withHandle`: the grip a pointer can see,
        # which is off by default there too.
        def initialize(with_handle: false, orientation: :horizontal, disabled: false, **attributes)
          @with_handle = with_handle
          @orientation = orientation&.to_sym == :vertical ? :vertical : :horizontal
          @disabled = disabled
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{
            role: "separator",
            # The group's orientation decides the separator's, inverted.
            "aria-orientation" => orientation == :vertical ? "horizontal" : "vertical",
            "aria-disabled" => (disabled.presence && "true"),
            tabindex: (disabled ? "-1" : "0"),
            "data-separator" => "inactive",
            "data-shadcn--resizable-target" => "handle",
            "data-action" => "pointerdown->shadcn--resizable#press keydown->shadcn--resizable#keydown",
            style: merged_style("flex-basis:auto;flex-grow:0;flex-shrink:0")
          }.compact.merge(defaults))
        end

        def call
          render_element(body: grip)
        end

        private

        def grip
          return unless with_handle

          tag.div(render(Icon::Component.new("grip-vertical", class: "size-2.5")), class: GRIP_CLASSES)
        end
      end
    end
  end
end
