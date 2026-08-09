# frozen_string_literal: true

module Shadcn
  module HoverCard
    module Trigger
      # HoverCardTrigger. Radix opens on hover *and* on focus and closes on blur
      # (hover-card.tsx:138-141), so a keyboard reaches the card even though it
      # cannot be tabbed into — see the content for the other half of that.
      #
      # `default_tag :button` because the demo's trigger is one and a hoverable
      # affordance needs to be focusable to open on focus at all; `as: :a` is
      # the usual override, which is what upstream's example passes.
      class Component < ApplicationViewComponent
        default_tag :button
        slot_name :"hover-card-trigger"

        def element_attributes(**defaults)
          attributes = {
            "data-state" => "closed",
            "data-shadcn--hover-card-target" => "trigger",
            "data-action" => "pointerenter->shadcn--hover-card#open " \
                             "pointerleave->shadcn--hover-card#close " \
                             "focus->shadcn--hover-card#open " \
                             "blur->shadcn--hover-card#close"
          }
          attributes[:type] = "button" if tag_name.to_sym == :button

          super(**attributes.merge(defaults))
        end
      end
    end
  end
end
