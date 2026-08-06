# frozen_string_literal: true

module Shadcn
  module Accordion
    # Port of registry/new-york-v4/ui/accordion.tsx
    #
    # Radix's Accordion.Root renders a plain div; the `shadcn--accordion`
    # Stimulus controller supplies the open/close state machine, the roving
    # arrow-key navigation and the ARIA wiring between triggers and panels.
    class Component < ApplicationViewComponent
      renders_many :items, "Shadcn::Accordion::Item::Component"

      slot_name :accordion

      attr_reader :type, :collapsible, :value, :orientation

      # @param type [:single, :multiple]
      # @param collapsible [Boolean] may the open item be closed again (single only)
      # @param value [String, Array] initially open item value(s)
      def initialize(type: :single, collapsible: false, value: nil, orientation: :vertical,
                     **attributes)
        @type = type&.to_sym || :single
        @collapsible = collapsible
        @value = Array(value).compact.join(",")
        @orientation = orientation&.to_sym || :vertical
        super(**attributes)
      end

      def element_attributes(**defaults)
        super(**{
          "data-orientation" => orientation,
          "data-controller" => "shadcn--accordion",
          "data-shadcn--accordion-type-value" => type,
          "data-shadcn--accordion-collapsible-value" => collapsible,
          "data-shadcn--accordion-value-value" => value
        }.merge(defaults))
      end

      def call
        render_element(body: safe_join([ items, content ].flatten.compact))
      end
    end
  end
end
