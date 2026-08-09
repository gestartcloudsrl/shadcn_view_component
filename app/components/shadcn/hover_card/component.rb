# frozen_string_literal: true

module Shadcn
  module HoverCard
    # Port of registry/new-york-v4/ui/hover-card.tsx, whose behaviour is Radix's
    # `HoverCard` — vendored at `vendor/radix/ui/hover-card.tsx`.
    #
    # A tooltip's larger relative, and the difference is what the delays are
    # for: this content is meant to be *entered*. Moving the pointer from the
    # trigger onto the card keeps it open, which is why the card carries the
    # same enter and leave handlers the trigger does.
    class Component < ApplicationViewComponent
      renders_one :trigger, "Shadcn::HoverCard::Trigger::Component"
      renders_one :hover_card_content, "Shadcn::HoverCard::Content::Component"

      slot_name :"hover-card"

      attr_reader :side, :align, :side_offset, :open_delay, :close_delay

      # `open_delay` and `close_delay` are Radix's own defaults
      # (vendor/radix/ui/hover-card.tsx:59-60), not numbers chosen here. The
      # closing one is the longer-lived decision of the two: it is the window in
      # which you can cross the gap between the trigger and the card.
      def initialize(side: :bottom, align: :center, side_offset: 4,
                     open_delay: 700, close_delay: 300, **attributes)
        @side = side&.to_sym || :bottom
        @align = align&.to_sym || :center
        @side_offset = side_offset
        @open_delay = open_delay
        @close_delay = close_delay
        super(**attributes)
      end

      def element_attributes(**defaults)
        super(**{
          style: merged_style(CONTENTS_STYLE),
          "data-controller" => "shadcn--hover-card",
          "data-shadcn--hover-card-side-value" => side,
          "data-shadcn--hover-card-align-value" => align,
          "data-shadcn--hover-card-side-offset-value" => side_offset,
          "data-shadcn--hover-card-open-delay-value" => open_delay,
          "data-shadcn--hover-card-close-delay-value" => close_delay
        }.merge(defaults))
      end

      def call
        render_element(body: safe_join([ trigger, hover_card_content, content ].compact))
      end
    end
  end
end
