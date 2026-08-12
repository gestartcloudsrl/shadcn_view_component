# frozen_string_literal: true

module Shadcn
  module ToggleGroup
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # Upstream's "Size" and "Disabled". Its "Vertical" is the other registry's.
      def sizes
        render_with_template
      end
    end
  end
end
