# frozen_string_literal: true

module Shadcn
  module Command
    class Preview < ApplicationViewComponentPreview
      # Upstream's own example: a palette in a box, with two groups and the
      # shortcuts beside the rows.
      def default
        render_with_template
      end

      # Upstream's "Dialog": the same list inside a Dialog. The shortcut that
      # opens it is the caller's — `data-action` on any element, or the Dialog's
      # own trigger.
      def dialog
        render_with_template
      end

      # What ranking buys, which filtering does not: type "gp" and Group Policy
      # comes first, because a palette answers "what did you mean".
      def ranking
        render_with_template
      end
    end
  end
end
