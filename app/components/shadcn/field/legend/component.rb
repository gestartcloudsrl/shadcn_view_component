# frozen_string_literal: true

module Shadcn
  module Field
    module Legend
      # FieldLegend
      class Component < ApplicationViewComponent
        default_tag :legend
        slot_name :"field-legend"

        style do
          base {
            "mb-3 font-medium data-[variant=legend]:text-base data-[variant=label]:text-sm"
          }
        end

        attr_reader :variant

        def initialize(variant: :legend, **attributes)
          @variant = variant&.to_sym || :legend
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{ "data-variant" => variant }.merge(defaults))
        end
      end
    end
  end
end
