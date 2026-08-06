# frozen_string_literal: true

module Shadcn
  module Button
    class Preview < ApplicationViewComponentPreview
      def default
        render_with_template
      end

      # @param variant select { choices: [default, destructive, outline, secondary, ghost, link] }
      # @param size select { choices: [default, xs, sm, lg, icon, icon-xs, icon-sm, icon-lg] }
      # @param disabled toggle
      def playground(variant: :default, size: :default, disabled: false)
        render_component(variant:, size:, disabled:) { "Button" }
      end

      def variants
        render_with_template
      end

      def sizes
        render_with_template
      end

      # `as:` is the equivalent of shadcn's `asChild`.
      def as_link
        render_component(as: :a, href: "#", variant: :link) { "A link that looks like a button" }
      end
    end
  end
end
