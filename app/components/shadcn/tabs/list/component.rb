# frozen_string_literal: true

module Shadcn
  module Tabs
    module List
      # TabsList
      class Component < ApplicationViewComponent
        renders_many :triggers, "Shadcn::Tabs::Trigger::Component"

        slot_name :"tabs-list"

        style do
          base {
            "group/tabs-list inline-flex w-fit items-center justify-center rounded-lg p-[3px] " \
            "text-muted-foreground group-data-[orientation=horizontal]/tabs:h-9 " \
            "group-data-[orientation=vertical]/tabs:h-fit " \
            "group-data-[orientation=vertical]/tabs:flex-col data-[variant=line]:rounded-none"
          }

          variants {
            variant {
              default { "bg-muted" }
              line { "gap-1 bg-transparent" }
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
          super(**{ role: "tablist", "data-variant" => variant }.merge(defaults))
        end

        def call
          render_element(body: safe_join([ triggers, content ].flatten.compact))
        end
      end
    end
  end
end
