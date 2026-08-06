# frozen_string_literal: true

module Shadcn
  module Collapsible
    # Port of registry/new-york-v4/ui/collapsible.tsx
    class Component < ApplicationViewComponent
      renders_one :trigger, "Shadcn::Collapsible::Trigger::Component"
      renders_one :panel, "Shadcn::Collapsible::Content::Component"

      slot_name :collapsible

      attr_reader :open, :disabled

      def initialize(open: false, disabled: false, **attributes)
        @open = open
        @disabled = disabled
        super(**attributes)
      end

      def element_attributes(**defaults)
        super(**{
          "data-state" => open ? "open" : "closed",
          "data-disabled" => (true if disabled),
          "data-controller" => "shadcn--collapsible",
          "data-shadcn--collapsible-open-value" => open,
          "data-shadcn--collapsible-disabled-value" => disabled
        }.merge(defaults))
      end

      def call
        render_element(body: safe_join([ trigger, panel, content ].compact))
      end
    end
  end
end
