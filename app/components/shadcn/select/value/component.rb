# frozen_string_literal: true

module Shadcn
  module Select
    module Value
      # SelectValue — the controller writes the chosen item's label in here.
      class Component < ApplicationViewComponent
        default_tag :span
        slot_name :"select-value"

        attr_reader :placeholder

        def initialize(placeholder: nil, **attributes)
          @placeholder = placeholder
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{ "data-shadcn--select-target" => "value" }.merge(defaults))
        end

        def call
          render_element(body: content.presence || placeholder)
        end
      end
    end
  end
end
