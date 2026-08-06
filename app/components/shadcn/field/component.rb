# frozen_string_literal: true

module Shadcn
  module Field
    # Port of registry/new-york-v4/ui/field.tsx
    class Component < ApplicationViewComponent
      renders_one :label, "Shadcn::Field::Label::Component"
      renders_one :field_content, "Shadcn::Field::Content::Component"
      renders_one :description, "Shadcn::Field::Description::Component"
      renders_one :error, "Shadcn::Field::Error::Component"

      slot_name :field

      style do
        base { "group/field flex w-full gap-3 data-[invalid=true]:text-destructive" }

        variants {
          orientation {
            vertical { "flex-col [&>*]:w-full [&>.sr-only]:w-auto" }
            horizontal {
              "flex-row items-center " \
              "[&>[data-slot=field-label]]:flex-auto " \
              "has-[>[data-slot=field-content]]:items-start " \
              "has-[>[data-slot=field-content]]:[&>[role=checkbox],[role=radio]]:mt-px"
            }
            responsive {
              # Class names are never split across line continuations: Tailwind
              # scans the source text, so half a token would generate no CSS.
              "flex-col @md/field-group:flex-row @md/field-group:items-center " \
              "[&>*]:w-full @md/field-group:[&>*]:w-auto [&>.sr-only]:w-auto " \
              "@md/field-group:[&>[data-slot=field-label]]:flex-auto " \
              "@md/field-group:has-[>[data-slot=field-content]]:items-start " \
              "@md/field-group:has-[>[data-slot=field-content]]:[&>[role=checkbox],[role=radio]]:mt-px"
            }
          }
        }

        defaults { { orientation: :vertical } }
      end

      attr_reader :orientation

      def initialize(orientation: :vertical, **attributes)
        @orientation = orientation&.to_sym || :vertical
        super(**attributes)
      end

      def style_variants
        { orientation: }
      end

      def element_attributes(**defaults)
        super(**{ role: "group", "data-orientation" => orientation }.merge(defaults))
      end

      def call
        render_element(body: safe_join([ label, field_content, content, description, error ].compact))
      end
    end
  end
end
