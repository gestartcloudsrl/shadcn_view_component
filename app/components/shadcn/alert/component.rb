# frozen_string_literal: true

module Shadcn
  module Alert
    # Port of registry/new-york-v4/ui/alert.tsx
    class Component < ApplicationViewComponent
      renders_one :title, "Shadcn::Alert::Title::Component"
      renders_one :description, "Shadcn::Alert::Description::Component"

      slot_name :alert

      style do
        base {
          "relative grid w-full grid-cols-[0_1fr] items-start gap-y-0.5 rounded-lg border " \
          "px-4 py-3 text-sm has-[>svg]:grid-cols-[calc(var(--spacing)*4)_1fr] " \
          "has-[>svg]:gap-x-3 [&>svg]:size-4 [&>svg]:translate-y-0.5 [&>svg]:text-current"
        }

        variants {
          variant {
            default { "bg-card text-card-foreground" }
            destructive {
              "bg-card text-destructive " \
              "*:data-[slot=alert-description]:text-destructive/90 [&>svg]:text-current"
            }
          }
        }

        defaults { { variant: :default } }
      end

      attr_reader :variant

      def initialize(variant: :default, **attributes)
        @variant = variant&.to_sym || :default
        super(**attributes)
      end

      def style_variants
        { variant: }
      end

      def element_attributes(**defaults)
        super(**{ role: "alert" }.merge(defaults))
      end

      def call
        render_element(body: safe_join([ title, description, content ].compact))
      end
    end
  end
end
