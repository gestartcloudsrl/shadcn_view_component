# frozen_string_literal: true

module Shadcn
  module ThemeSelector
    class Preview < ApplicationViewComponentPreview
      # The base colours a project picks from.
      def default
        render_with_template
      end

      # Every palette in the registry, accents included.
      def all_themes
        render_with_template
      end
    end
  end
end
