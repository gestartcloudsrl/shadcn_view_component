# frozen_string_literal: true

module Shadcn
  module DropdownMenu
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # Upstream's "Checkboxes", "Radio Group" and "Destructive".
      def checkboxes_and_radio
        render_with_template
      end
    end
  end
end
