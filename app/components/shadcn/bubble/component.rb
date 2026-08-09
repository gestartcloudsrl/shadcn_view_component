# frozen_string_literal: true

module Shadcn
  module Bubble
    # Port of registry/new-york-v4/ui/bubble.tsx
    #
    # Every variant here styles the *child* rather than this element: they are
    # all `*:data-[slot=bubble-content]:…` selectors, so a Bubble with no
    # Content inside it renders no colour at all. That is upstream's arrangement,
    # not a simplification — the bubble owns the layout and the content owns the
    # surface.
    class Component < ApplicationViewComponent
      slot_name :bubble

      style do
        base {
          "group/bubble relative flex w-fit max-w-[80%] min-w-0 flex-col gap-1 " \
          "group-data-[align=end]/message:self-end data-[align=end]:self-end " \
          "data-[variant=ghost]:max-w-full"
        }

        variants {
          variant {
            default {
              "*:data-[slot=bubble-content]:bg-primary " \
              "*:data-[slot=bubble-content]:text-primary-foreground " \
              "[&>[data-slot=bubble-content]:is(button,a):hover]:bg-primary/80"
            }
            secondary {
              "*:data-[slot=bubble-content]:bg-secondary " \
              "*:data-[slot=bubble-content]:text-secondary-foreground " \
              "[&>[data-slot=bubble-content]:is(button,a):hover]:bg-[color-mix(in_oklch,var(--secondary),var(--foreground)_5%)]"
            }
            muted {
              "*:data-[slot=bubble-content]:bg-muted " \
              "[&>[data-slot=bubble-content]:is(button,a):hover]:bg-[color-mix(in_oklch,var(--muted),var(--foreground)_5%)]"
            }
            tinted {
              "*:data-[slot=bubble-content]:bg-[oklch(from_var(--primary)_0.93_calc(c*0.4)_h)] " \
              "*:data-[slot=bubble-content]:text-foreground " \
              "dark:*:data-[slot=bubble-content]:bg-[oklch(from_var(--primary)_0.3_calc(c*0.4)_h)] " \
              "[&>[data-slot=bubble-content]:is(button,a):hover]:bg-[oklch(from_var(--primary)_0.88_calc(c*0.5)_h)] " \
              "dark:[&>[data-slot=bubble-content]:is(button,a):hover]:bg-[oklch(from_var(--primary)_0.35_calc(c*0.5)_h)]"
            }
            outline {
              "*:data-[slot=bubble-content]:border-border " \
              "*:data-[slot=bubble-content]:bg-background " \
              "[&>[data-slot=bubble-content]:is(button,a):hover]:bg-muted " \
              "[&>[data-slot=bubble-content]:is(button,a):hover]:text-foreground " \
              "dark:[&>[data-slot=bubble-content]:is(button,a):hover]:bg-input/30"
            }
            ghost {
              "border-none *:data-[slot=bubble-content]:rounded-none " \
              "*:data-[slot=bubble-content]:bg-transparent " \
              "*:data-[slot=bubble-content]:p-0 " \
              "[&>[data-slot=bubble-content]:is(button,a):hover]:bg-muted " \
              "[&>[data-slot=bubble-content]:is(button,a):hover]:text-foreground " \
              "dark:[&>[data-slot=bubble-content]:is(button,a):hover]:bg-muted/50"
            }
            destructive {
              "*:data-[slot=bubble-content]:bg-destructive/10 " \
              "*:data-[slot=bubble-content]:text-destructive " \
              "dark:*:data-[slot=bubble-content]:bg-destructive/20 " \
              "[&>[data-slot=bubble-content]:is(button,a):hover]:bg-destructive/20 " \
              "dark:[&>[data-slot=bubble-content]:is(button,a):hover]:bg-destructive/30"
            }
          }
        }

        defaults { { variant: :default } }
      end

      attr_reader :variant, :align

      def initialize(variant: :default, align: :start, **attributes)
        @variant = variant&.to_sym || :default
        @align = align&.to_sym || :start
        super(**attributes)
      end

      def style_variants
        { variant: }
      end

      def element_attributes(**defaults)
        super(**{ "data-variant" => variant, "data-align" => align }.merge(defaults))
      end
    end
  end
end
