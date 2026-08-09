# frozen_string_literal: true

module Shadcn
  module HoverCard
    module Content
      # HoverCardContent.
      #
      # It carries the same pointer handlers as the trigger, and that is the
      # component rather than a detail: without them, moving onto the card is
      # leaving the trigger and the card closes under the pointer that went for
      # it (hover-card.tsx:220-221).
      #
      # No `role` and no `aria-*`, which is Radix's own — measured, there is not
      # one of either in the whole primitive. The card is a sighted-hover
      # affordance, and nothing in it is announced. That is also why every
      # tabbable inside it is taken out of the tab order; the controller does
      # that, since the content is a host's markup rather than this component's.
      class Component < ApplicationViewComponent
        slot_name :"hover-card-content"

        style do
          base {
            "z-50 w-64 origin-(--radix-hover-card-content-transform-origin) rounded-md " \
            "border bg-popover p-4 text-popover-foreground shadow-md outline-hidden " \
            "data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 " \
            "data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 " \
            "data-[state=closed]:animate-out data-[state=closed]:fade-out-0 " \
            "data-[state=closed]:zoom-out-95 data-[state=open]:animate-in " \
            "data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95"
          }
        end

        def element_attributes(**defaults)
          super(**{
            hidden: true,
            "data-state" => "closed",
            "data-shadcn--hover-card-target" => "content",
            "data-action" => "pointerenter->shadcn--hover-card#open " \
                             "pointerleave->shadcn--hover-card#close"
          }.merge(defaults))
        end
      end
    end
  end
end
