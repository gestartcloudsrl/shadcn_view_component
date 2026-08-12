# frozen_string_literal: true

module Shadcn
  module InputOtp
    # Port of registry/new-york-v4/ui/input-otp.tsx
    #
    # Upstream builds this on the **input-otp** package, and this port does not.
    # Measured: of its 715 lines, `input-otp.tsx` uses the root component and,
    # per box, three values — `char`, `isActive` and `hasFakeCaret`. The rule
    # behind them is six lines (input.tsx:596-618), and the mechanism under it
    # is one real `<input>` laid invisibly over the boxes, which is what makes
    # typing, paste, backspace, the arrow keys and a one-time-code autofill the
    # browser's problem rather than ours.
    #
    # What the 715 lines mostly are is the part that cannot be ported by
    # reading: 21 of them name Safari, iOS, a password manager or a selection
    # quirk. features/input-otp.md says which of those this port answers and
    # which it does not.
    #
    # The shape is upstream's, read from the rendered demo rather than from the
    # TSX, which shows none of it: the boxes come first, and the input sits over
    # them in an absolutely positioned layer.
    class Component < ApplicationViewComponent
      slot_name :"input-otp-container"

      style do
        base { "flex items-center gap-2 has-disabled:opacity-50" }
      end

      # Everything the input needs to be a real one. `disabled:cursor-not-allowed`
      # is upstream's class for it; the rest of its look is a rule in
      # `shadcn.css`, because it is a technique rather than a style — see there.
      INPUT_CLASSES = "disabled:cursor-not-allowed"

      attr_reader :max_length, :name, :value, :disabled, :pattern, :autofocus, :input_attributes

      def initialize(max_length: 6, name: nil, value: nil, disabled: false, pattern: nil,
                     autofocus: false, input: {}, **attributes)
        @max_length = max_length.to_i
        @name = name
        @value = value.to_s
        @disabled = disabled
        @pattern = pattern
        @autofocus = autofocus
        @input_attributes = input
        super(**attributes)
      end

      def element_attributes(**defaults)
        super(**{
          style: merged_style("position:relative"),
          "data-controller" => "shadcn--input-otp",
          "data-shadcn--input-otp-length-value" => max_length
        }.merge(defaults))
      end

      def call
        render_element(body: safe_join([ content, overlay ]))
      end

      private

      # Upstream's own arrangement: the boxes are the page, and the input is a
      # layer over them that takes the pointer while the layer itself does not.
      def overlay
        tag.div(input, style: "position:absolute;inset:0;pointer-events:none")
      end

      def input
        tag.input(**{
          "data-slot": "input-otp",
          "data-shadcn--input-otp-target": "input",
          "data-action": "input->shadcn--input-otp#entered " \
                         "select->shadcn--input-otp#refresh " \
                         "keyup->shadcn--input-otp#refresh " \
                         "click->shadcn--input-otp#refresh " \
                         "focus->shadcn--input-otp#focus " \
                         "blur->shadcn--input-otp#refresh",
          class: INPUT_CLASSES,
          value: value.presence,
          name:,
          maxlength: max_length,
          disabled: (true if disabled),
          autofocus: (true if autofocus),
          pattern:,
          # The three that make a phone offer the code from a message, and stop
          # a keyboard offering everything else.
          autocomplete: "one-time-code",
          inputmode: "numeric",
          spellcheck: "false"
        }.compact.merge(input_attributes))
      end
    end
  end
end
