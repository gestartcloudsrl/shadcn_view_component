# frozen_string_literal: true

module Shadcn
  module Combobox
    module Content
      # The panel. Its class string is where Base UI's conventions are most
      # visible — `data-open:`, `data-closed:`, `--anchor-width`,
      # `--available-width`, `--transform-origin` — and reproducing it is why
      # the controller asks `popper.js` to publish those four unprefixed names
      # beside the `--radix-*` ones it already computes.
      class Component < ApplicationViewComponent
        default_tag :div
        slot_name :"combobox-content"

        style do
          base {
            # `isolate z-50` is upstream's *Positioner*, which this port has no
            # element for — `floating.js` makes the wrapper — so they ride on
            # the panel itself.
            "isolate z-50 group/combobox-content relative max-h-96 w-(--anchor-width) max-w-(--available-width) " \
            "min-w-[calc(var(--anchor-width)+--spacing(7))] origin-(--transform-origin) overflow-hidden " \
            "rounded-md bg-popover text-popover-foreground shadow-md ring-1 ring-foreground/10 duration-100 " \
            "data-[chips=true]:min-w-(--anchor-width) data-[side=bottom]:slide-in-from-top-2 " \
            "data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 " \
            "data-[side=top]:slide-in-from-bottom-2 *:data-[slot=input-group]:m-1 " \
            "*:data-[slot=input-group]:mb-0 *:data-[slot=input-group]:h-8 " \
            "*:data-[slot=input-group]:border-input/30 *:data-[slot=input-group]:bg-input/30 " \
            "*:data-[slot=input-group]:shadow-none data-open:animate-in data-open:fade-in-0 " \
            "data-open:zoom-in-95 data-closed:animate-out data-closed:fade-out-0 data-closed:zoom-out-95"
          }
        end

        attr_reader :side, :align, :side_offset, :align_offset

        def initialize(side: :bottom, align: :start, side_offset: 6, align_offset: 0, **attributes)
          @side = side&.to_sym || :bottom
          @align = align&.to_sym || :start
          @side_offset = side_offset
          @align_offset = align_offset
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{
            role: "listbox",
            hidden: true,
            "data-closed" => "",
            "data-side" => side,
            "data-shadcn--combobox-target" => "content",
            "data-shadcn--combobox-side-value" => side,
            "data-shadcn--combobox-align-value" => align,
            "data-shadcn--combobox-side-offset-value" => side_offset,
            "data-shadcn--combobox-align-offset-value" => align_offset
          }.merge(defaults))
        end
      end
    end
  end
end
