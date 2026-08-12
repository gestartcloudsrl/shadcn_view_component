# frozen_string_literal: true

module Shadcn
  module Toaster
    module Toast
      # One toast.
      #
      # A real component rather than a shape the JavaScript builds, because the
      # most useful way to raise one in a Rails app is from the server: a flash
      # rendered with the page, or a `turbo_stream.append` onto the list. The
      # controller then only has to start its clock and take it away again.
      class Component < ApplicationViewComponent
        VARIANTS = {
          default: nil,
          success: "circle-check",
          info: "info",
          warning: "triangle-alert",
          error: "octagon-x",
          loading: "loader-circle"
        }.freeze

        default_tag :li
        slot_name :toast

        style do
          base {
            # sonner's own measurements, read from its stylesheet: 356px wide,
            # 16px of padding, a 13px face and a soft shadow. The colours are
            # the four custom properties `sonner.tsx` sets — popover, its
            # foreground, the border and the radius — written here as the
            # Tailwind tokens they point at.
            # Absolutely placed: the toasts are a *stack*, one behind another,
            # and the controller writes where each sits. A column would be
            # simpler and would not be this component — the fan-out on hover is
            # what a toaster is.
            #
            # The movement is a transition rather than a keyframe animation, as
            # sonner's is: a toast moves whenever the one in front of it goes
            # away, and an animation would have to be restarted each time where
            # a transition simply follows.
            "pointer-events-auto absolute right-0 flex w-full items-start gap-3 overflow-hidden " \
            "rounded-lg border bg-popover p-4 text-[13px] text-popover-foreground " \
            "shadow-[0_4px_12px_rgba(0,0,0,0.1)] transition-all duration-[400ms] " \
            "data-[state=closed]:opacity-0"
          }

          variants {
            variant {
              default { "" }
              success { "[&_[data-slot=toast-icon]]:text-emerald-600 dark:[&_[data-slot=toast-icon]]:text-emerald-400" }
              info { "[&_[data-slot=toast-icon]]:text-blue-600 dark:[&_[data-slot=toast-icon]]:text-blue-400" }
              warning { "[&_[data-slot=toast-icon]]:text-amber-600 dark:[&_[data-slot=toast-icon]]:text-amber-400" }
              error { "[&_[data-slot=toast-icon]]:text-destructive" }
              loading { "[&_[data-slot=toast-icon]]:animate-spin" }
            }
          }

          defaults { { variant: :default } }
        end

        renders_one :action, "Shadcn::Button::Component"

        attr_reader :variant, :title, :description, :duration, :dismissible

        def initialize(title: nil, description: nil, variant: :default, duration: nil,
                       dismissible: true, **attributes)
          @variant = VARIANTS.key?(variant&.to_sym) ? variant.to_sym : :default
          @title = title
          @description = description
          @duration = duration
          @dismissible = dismissible
          super(**attributes)
        end

        def style_variants = { variant: }

        def element_attributes(**defaults)
          # No `role` here, and sonner sets none either (index.tsx renders a bare
          # `<li>`): a role on an `<li>` replaces its implicit `listitem`, and
          # an `<ol>` whose children are not list items is a list axe fails and
          # a screen reader miscounts. The announcement comes from the region's
          # `aria-live`, which is where sonner puts it too (index.tsx:790).
          super(**{
            "data-variant" => variant,
            "data-state" => "open",
            "data-duration" => duration,
            "data-shadcn--toaster-target" => "toast"
          }.compact.merge(defaults))
        end

        def call
          render_element(body: safe_join([ icon, body, dismiss ].compact))
        end

        private

        def icon
          name = VARIANTS[variant]
          return unless name

          render(Icon::Component.new(name, class: "size-4 shrink-0", "data-slot": "toast-icon"))
        end

        def body
          tag.div(class: "flex min-w-0 flex-1 flex-col gap-1") do
            safe_join([
              (tag.div(title, class: "font-medium", "data-slot": "toast-title") if title),
              (tag.div(description, class: "text-muted-foreground", "data-slot": "toast-description") if description),
              (tag.div(action, class: "pt-1") if action?),
              content
            ].compact)
          end
        end

        def dismiss
          return unless dismissible

          # Always visible, where sonner reveals its own on hover. sonner can
          # afford to hide it because a toast there is also dismissed by
          # swiping it away; this port has no swipe, so the button is the only
          # way out — and a control that appears on hover is not a control on a
          # phone.
          tag.button(
            type: "button",
            class: "absolute top-2 right-2 rounded-sm text-muted-foreground transition-colors " \
                   "hover:text-foreground",
            "aria-label": shadcn_t("toaster.dismiss"),
            "data-action": "click->shadcn--toaster#dismiss"
          ) { render(Icon::Component.new("x", class: "size-4")) }
        end
      end
    end
  end
end
