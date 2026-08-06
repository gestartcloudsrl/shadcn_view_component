# frozen_string_literal: true

module Shadcn
  module Dialog
    module Overlay
      # DialogOverlay
      class Component < ApplicationViewComponent
        slot_name :"dialog-overlay"

        style do
          base {
            "fixed inset-0 z-50 bg-black/50 data-[state=closed]:animate-out " \
            "data-[state=closed]:fade-out-0 data-[state=open]:animate-in " \
            "data-[state=open]:fade-in-0"
          }
        end

        def element_attributes(**defaults)
          super(**{
            "data-state" => "closed",
            hidden: true,
            "data-shadcn--dialog-target" => "overlay"
          }.merge(defaults))
        end
      end
    end
  end
end
