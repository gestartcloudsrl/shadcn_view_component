# frozen_string_literal: true

module Shadcn
  module InputGroup
    module Addon
      # InputGroupAddon. The one part of this family that is not just markup:
      # upstream gives it an `onClick` that focuses the group's input, unless
      # the click landed on a button. That is the `focusControl` action.
      class Component < ApplicationViewComponent
        slot_name :"input-group-addon"

        style do
          base {
            "flex h-auto cursor-text items-center justify-center gap-2 py-1.5 text-sm " \
            "font-medium text-muted-foreground select-none " \
            "group-data-[disabled=true]/input-group:opacity-50 " \
            "[&>kbd]:rounded-[calc(var(--radius)-5px)] " \
            "[&>svg:not([class*='size-'])]:size-4"
          }

          variants {
            align {
              # The keys keep upstream's spelling, which is not valid Ruby.
              send(:"inline-start") {
                "order-first pl-3 has-[>button]:ml-[-0.45rem] has-[>kbd]:ml-[-0.35rem]"
              }
              send(:"inline-end") {
                "order-last pr-3 has-[>button]:mr-[-0.45rem] has-[>kbd]:mr-[-0.35rem]"
              }
              send(:"block-start") {
                "order-first w-full justify-start px-3 pt-3 " \
                "group-has-[>input]/input-group:pt-2.5 [.border-b]:pb-3"
              }
              send(:"block-end") {
                "order-last w-full justify-start px-3 pb-3 " \
                "group-has-[>input]/input-group:pb-2.5 [.border-t]:pt-3"
              }
            }
          }

          defaults { { align: :"inline-start" } }
        end

        attr_reader :align

        def initialize(align: :"inline-start", **attributes)
          @align = align&.to_sym || :"inline-start"
          super(**attributes)
        end

        def style_variants
          { align: }
        end

        def element_attributes(**defaults)
          super(**{
            role: "group",
            "data-align" => align,
            "data-action" => "click->shadcn--input-group#focusControl"
          }.merge(defaults))
        end
      end
    end
  end
end
