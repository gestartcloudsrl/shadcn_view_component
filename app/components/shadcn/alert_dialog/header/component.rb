# frozen_string_literal: true

module Shadcn
  module AlertDialog
    module Header
      # AlertDialogHeader
      class Component < ApplicationViewComponent
        renders_one :media, "Shadcn::AlertDialog::Media::Component"
        renders_one :title, "Shadcn::AlertDialog::Title::Component"
        renders_one :description, "Shadcn::AlertDialog::Description::Component"

        slot_name :"alert-dialog-header"

        style do
          base {
            # Class names are never split across line continuations: Tailwind
            # scans the source text, so half a token would generate no CSS.
            "grid grid-rows-[auto_1fr] place-items-center gap-1.5 text-center " \
            "has-data-[slot=alert-dialog-media]:grid-rows-[auto_auto_1fr] " \
            "has-data-[slot=alert-dialog-media]:gap-x-6 " \
            "sm:group-data-[size=default]/alert-dialog-content:place-items-start " \
            "sm:group-data-[size=default]/alert-dialog-content:text-left " \
            "sm:group-data-[size=default]/alert-dialog-content:has-data-[slot=alert-dialog-media]:grid-rows-[auto_1fr]"
          }
        end

        def call
          render_element(body: safe_join([ media, title, description, content ].compact))
        end
      end
    end
  end
end
