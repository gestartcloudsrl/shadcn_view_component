# frozen_string_literal: true

module Shadcn
  module ScrollArea
    module Viewport
      # The box that actually scrolls. Native scrollbars are hidden on it —
      # `shadcn.css` carries the rule Radix injects as a `<style>` tag
      # (vendor/radix/ui/scroll-area.tsx:266-278), keyed on the slot rather than
      # on a class, so a host cannot switch it off by accident and there is no
      # token for `parity_spec` to miss.
      #
      # `overflow` is inline and per axis, as Radix writes it (`:222-223`):
      # `scroll` on an axis with a scrollbar, `hidden` on one without. It has to
      # be `scroll` rather than `auto` — the element must keep its scrollable
      # geometry even when the custom bar is the only thing showing it.
      class Component < ApplicationViewComponent
        slot_name :"scroll-area-viewport"

        style do
          base {
            "size-full rounded-[inherit] transition-[color,box-shadow] outline-none " \
            "focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-1"
          }
        end

        attr_reader :horizontal, :vertical

        def initialize(horizontal: false, vertical: true, **attributes)
          @horizontal = horizontal
          @vertical = vertical
          super(**attributes)
        end

        # `tabindex: 0`, which Radix does **not** set — measured, there is no
        # `tabIndex` anywhere in the primitive. A deliberate divergence, for
        # three reasons that line up: axe fails a scrollable region with no
        # keyboard access; Chrome and Firefox make scrollers focusable
        # themselves and Safari does not, so without this the component's
        # keyboard behaviour depends on the browser; and shadcn's own classes
        # here style `focus-visible`, which only means anything on an element
        # that can be focused. The sibling primitive shadcn publishes does set
        # it on its viewport (`vendor/shadcn-react/message-scroller/components.tsx:209`).
        def element_attributes(**defaults)
          super(**{
            tabindex: 0,
            style: merged_style(
              "overflow-x: #{horizontal ? 'scroll' : 'hidden'}; " \
              "overflow-y: #{vertical ? 'scroll' : 'hidden'};"
            ),
            "data-shadcn--scroll-area-target" => "viewport"
          }.merge(defaults))
        end

        # `display: table` with `min-width: 100%`, which is Radix's own
        # (`:296-299`) and is the only reason content *size* can be measured at
        # all: a block child matches the viewport's width and would report the
        # same number however wide its content really is.
        def call
          render_element(
            body: tag.div(
              content,
              style: "min-width: 100%; display: table;",
              "data-shadcn--scroll-area-target": "content"
            )
          )
        end
      end
    end
  end
end
