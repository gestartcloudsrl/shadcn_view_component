# frozen_string_literal: true

module Shadcn
  module Card
    # Port of registry/new-york-v4/ui/card.tsx
    class Component < ApplicationViewComponent
      renders_one :header, "Shadcn::Card::Header::Component"
      renders_one :card_content, "Shadcn::Card::Content::Component"
      renders_one :footer, "Shadcn::Card::Footer::Component"

      slot_name :card

      style do
        base {
          "flex flex-col gap-6 rounded-xl border bg-card py-6 text-card-foreground shadow-sm"
        }
      end

      def call
        render_element(body: safe_join([ header, card_content, footer, content ].compact))
      end
    end
  end
end
