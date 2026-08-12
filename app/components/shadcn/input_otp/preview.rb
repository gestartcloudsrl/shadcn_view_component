# frozen_string_literal: true

module Shadcn
  module InputOtp
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # Upstream's "Pattern", "Separator" and "Disabled" — and the FormBuilder,
      # since a code that is not submitted is a code for nothing.
      def variations
        render_with_template
      end
    end
  end
end
