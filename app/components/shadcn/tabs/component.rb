# frozen_string_literal: true

module Shadcn
  module Tabs
    # Port of registry/new-york-v4/ui/tabs.tsx
    class Component < ApplicationViewComponent
      renders_one :list, "Shadcn::Tabs::List::Component"
      renders_many :panels, "Shadcn::Tabs::Content::Component"

      slot_name :tabs

      style do
        base { "group/tabs flex gap-2 data-[orientation=horizontal]:flex-col" }
      end

      attr_reader :orientation, :value, :activation

      def initialize(value: nil, orientation: :horizontal, activation: :automatic, **attributes)
        @value = value.to_s
        @orientation = orientation&.to_sym || :horizontal
        @activation = activation&.to_sym || :automatic
        super(**attributes)
      end

      def element_attributes(**defaults)
        super(**{
          "data-orientation" => orientation,
          "data-controller" => "shadcn--tabs",
          "data-shadcn--tabs-value-value" => value,
          "data-shadcn--tabs-orientation-value" => orientation,
          "data-shadcn--tabs-activation-value" => activation
        }.merge(defaults))
      end

      def call
        render_element(body: safe_join([ list, panels, content ].flatten.compact))
      end
    end
  end
end
