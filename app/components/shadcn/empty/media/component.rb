# frozen_string_literal: true

module Shadcn
  module Empty
    module Media
      # EmptyMedia. Named after the TSX function, but the `data-slot` it emits
      # is `empty-icon` — the two differ upstream, and the slot is what the
      # sibling selectors key on.
      class Component < ApplicationViewComponent
        slot_name :"empty-icon"

        style do
          base {
            "mb-2 flex shrink-0 items-center justify-center [&_svg]:pointer-events-none " \
            "[&_svg]:shrink-0"
          }

          variants {
            variant {
              default { "bg-transparent" }
              icon {
                "flex size-10 shrink-0 items-center justify-center rounded-lg bg-muted " \
                "text-foreground [&_svg:not([class*='size-'])]:size-6"
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
          super(**{ "data-variant" => variant }.merge(defaults))
        end
      end
    end
  end
end
