# frozen_string_literal: true

module Shadcn
  module Avatar
    # Port of registry/new-york-v4/ui/avatar.tsx
    #
    # Radix swaps the image for the fallback based on the image's loading state;
    # the `shadcn--avatar` Stimulus controller does the same here.
    class Component < ApplicationViewComponent
      renders_one :image, "Shadcn::Avatar::Image::Component"
      renders_one :fallback, "Shadcn::Avatar::Fallback::Component"
      renders_one :badge, "Shadcn::Avatar::Badge::Component"

      default_tag :span
      slot_name :avatar

      style do
        base {
          "group/avatar relative flex size-8 shrink-0 overflow-hidden rounded-full " \
          "select-none data-[size=lg]:size-10 data-[size=sm]:size-6"
        }
      end

      attr_reader :size

      def initialize(size: :default, **attributes)
        @size = size&.to_sym || :default
        super(**attributes)
      end

      def element_attributes(**defaults)
        super(**{
          "data-size" => size,
          "data-controller" => "shadcn--avatar"
        }.merge(defaults))
      end

      def call
        render_element(body: safe_join([ image, fallback, badge, content ].compact))
      end
    end
  end
end
