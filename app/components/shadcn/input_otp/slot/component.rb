# frozen_string_literal: true

module Shadcn
  module InputOtp
    module Slot
      # InputOTPSlot — one box. It holds no state of its own: the character, the
      # active mark and the caret are all written by the controller from the one
      # input's value and selection.
      #
      # Upstream takes an `index`; this reads the boxes in the order they appear,
      # which is the same answer without a number for a caller to get wrong.
      class Component < ApplicationViewComponent
        CARET_CLASSES = "pointer-events-none absolute inset-0 flex items-center justify-center"
        BAR_CLASSES = "h-4 w-px animate-caret-blink bg-foreground duration-1000"

        slot_name :"input-otp-slot"

        style do
          base {
            "relative flex h-9 w-9 items-center justify-center border-y border-r border-input " \
            "text-sm shadow-xs transition-all outline-none first:rounded-l-md first:border-l " \
            "last:rounded-r-md aria-invalid:border-destructive data-[active=true]:z-10 " \
            "data-[active=true]:border-ring data-[active=true]:ring-[3px] " \
            "data-[active=true]:ring-ring/50 data-[active=true]:aria-invalid:border-destructive " \
            "data-[active=true]:aria-invalid:ring-destructive/20 dark:bg-input/30 " \
            "dark:data-[active=true]:aria-invalid:ring-destructive/40"
          }
        end

        def element_attributes(**defaults)
          super(**{
            "data-active" => "false",
            "data-shadcn--input-otp-target" => "slot"
          }.merge(defaults))
        end

        def call
          render_element(body: safe_join([ character, caret ]))
        end

        private

        def character
          tag.span("data-shadcn--input-otp-target": "char")
        end

        # Rendered always and hidden until the box is both active and empty,
        # which is upstream's `hasFakeCaret`. Server-rendered rather than
        # created on demand: a component that adds elements from JavaScript is a
        # component `turbo:morph` argues with.
        def caret
          tag.div(tag.div(class: BAR_CLASSES),
                  class: CARET_CLASSES,
                  hidden: true,
                  "data-shadcn--input-otp-target": "caret")
        end
      end
    end
  end
end
