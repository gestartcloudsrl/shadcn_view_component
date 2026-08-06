# frozen_string_literal: true

module Shadcn
  module AlertDialog
    module Action
      # AlertDialogAction — shadcn wraps it in `<Button asChild>`, so it carries
      # the button's classes while staying the dialog's action element.
      class Component < ApplicationViewComponent
        default_tag :button
        slot_name :"alert-dialog-action"

        attr_reader :variant, :size

        def initialize(variant: :default, size: :default, **attributes)
          @variant = variant&.to_sym || :default
          @size = size&.to_sym || :default
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{
            type: "button",
            "data-variant" => variant,
            "data-size" => size,
            "data-action" => "shadcn--dialog#close"
          }.merge(defaults))
        end

        def css_classes(extra = nil)
          Button::Component.variant_classes(variant:, size:, class: extra)
        end
      end
    end
  end
end
