# frozen_string_literal: true

module Shadcn
  module Field
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # The same components driven by `shadcn_form_with`, so ids, names, error
      # text and the ARIA wiring come from the model.
      def form_builder
        render_with_template
      end
    end
  end
end
