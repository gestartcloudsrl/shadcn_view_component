# frozen_string_literal: true

module Shadcn
  module AlertDialog
    module Content
      # AlertDialogContent — `role="alertdialog"`, no dismiss button.
      class Component < ApplicationViewComponent
        renders_one :header, "Shadcn::AlertDialog::Header::Component"
        renders_one :footer, "Shadcn::AlertDialog::Footer::Component"

        slot_name :"alert-dialog-content"

        style do
          base {
            "group/alert-dialog-content fixed top-[50%] left-[50%] z-50 grid w-full " \
            "max-w-[calc(100%-2rem)] translate-x-[-50%] translate-y-[-50%] gap-4 rounded-lg " \
            "border bg-background p-6 shadow-lg duration-200 data-[size=sm]:max-w-xs " \
            "data-[state=closed]:animate-out data-[state=closed]:fade-out-0 " \
            "data-[state=closed]:zoom-out-95 data-[state=open]:animate-in " \
            "data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95 " \
            "data-[size=default]:sm:max-w-lg"
          }
        end

        attr_reader :size

        def initialize(size: :default, **attributes)
          @size = size&.to_sym || :default
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{
            role: "alertdialog",
            "aria-modal" => "true",
            tabindex: "-1",
            "data-size" => size,
            "data-state" => "closed",
            hidden: true,
            "data-shadcn--dialog-target" => "content"
          }.merge(defaults))
        end

        def call
          tag.div("data-slot": "alert-dialog-portal", style: CONTENTS_STYLE) do
            safe_join([
              render(Overlay::Component.new),
              render_element(body: safe_join([ header, content, footer ].compact))
            ])
          end
        end
      end
    end
  end
end
