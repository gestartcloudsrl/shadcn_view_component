# frozen_string_literal: true

module Shadcn
  module Attachment
    # Port of registry/new-york-v4/ui/attachment.tsx
    #
    # `state:` is not a cva variant upstream and is not one here: it is written
    # as `data-state` and read by selectors on this element and on its children
    # — `data-[state=idle]:border-dashed` here, and
    # `group-data-[state=error]/attachment:…` on the media and the description
    # (attachment.tsx:9 and :49). Only `size` and `orientation` choose classes.
    class Component < ApplicationViewComponent
      slot_name :attachment

      style do
        base {
          "group/attachment relative flex w-fit max-w-full min-w-0 shrink-0 flex-wrap " \
          "rounded-xl border bg-card text-card-foreground transition-colors " \
          "focus-within:ring-1 focus-within:ring-ring/50 has-[>a,>button]:hover:bg-muted/50 " \
          "data-[state=error]:border-destructive/30 data-[state=idle]:border-dashed"
        }

        variants {
          size {
            default {
              "gap-2 text-sm has-data-[slot=attachment-content]:px-2.5 " \
              "has-data-[slot=attachment-content]:py-2 " \
              "has-data-[slot=attachment-media]:p-2"
            }
            sm {
              "gap-2.5 text-xs has-data-[slot=attachment-content]:px-2 " \
              "has-data-[slot=attachment-content]:py-1.5 " \
              "has-data-[slot=attachment-media]:p-1.5"
            }
            xs {
              "gap-1.5 rounded-lg text-xs has-data-[slot=attachment-content]:px-1.5 " \
              "has-data-[slot=attachment-content]:py-1 " \
              "has-data-[slot=attachment-media]:p-1"
            }
          }

          orientation {
            horizontal { "min-w-40 items-center" }
            vertical { "w-24 flex-col has-data-[slot=attachment-content]:w-30" }
          }
        }

        # Upstream's cva declares no `defaultVariants` — the defaults live on the
        # function's own parameters instead (attachment.tsx:28-30). Same values,
        # and here there is only one place to put them.
        defaults { { size: :default, orientation: :horizontal } }
      end

      attr_reader :state, :size, :orientation

      def initialize(state: :done, size: :default, orientation: :horizontal, **attributes)
        @state = state&.to_sym || :done
        @size = size&.to_sym || :default
        @orientation = orientation&.to_sym || :horizontal
        super(**attributes)
      end

      def style_variants
        { size:, orientation: }
      end

      def element_attributes(**defaults)
        super(**{
          "data-state" => state,
          "data-size" => size,
          "data-orientation" => orientation
        }.merge(defaults))
      end
    end
  end
end
