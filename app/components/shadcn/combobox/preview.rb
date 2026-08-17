# frozen_string_literal: true

module Shadcn
  module Combobox
    class Preview < ApplicationViewComponentPreview
      # Upstream's own first example: type to filter, arrows to walk, Enter to
      # take.
      def default
        render_with_template
      end

      # Upstream's "Clear": the X that empties the field, which hides the
      # chevron while it is there — upstream's own rule, in a class.
      def with_clear
        render_with_template
      end

      # Groups with labels, and the separator between them.
      def grouped
        render_with_template
      end

      # Multiple selection: the chips box in place of the field. Two values
      # start chosen, so the server-rendered half — the ticks, the chips and the
      # hidden inputs agreeing before anything is clicked — is covered too.
      def multiple
        render_with_template
      end
    end
  end
end
