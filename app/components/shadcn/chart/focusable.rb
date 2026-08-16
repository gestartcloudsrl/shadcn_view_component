# frozen_string_literal: true

module Shadcn
  module Chart
    # What makes a chart reachable without a pointer, shared by every shape.
    #
    # This is upstream's own shape, read from the rendered example rather than
    # from source — nothing of recharts is vendored here. Its
    # `accessibilityLayer` puts `role="application" tabindex="0"` on the
    # surface, and `application` is not decoration: it is what stops a screen
    # reader from swallowing the arrow keys before they reach the page.
    #
    # Where this port diverges: upstream leaves the graphic itself exposed, so
    # its axis labels reach the accessibility tree as loose text — *"400 300 200
    # 100 0 January February …"*. Here the drawing sits inside an
    # `aria-hidden` group, so the element that takes focus is not hidden — the
    # pair is what axe calls `aria-hidden-focus` — and nothing inside it is
    # read twice. The numbers are the table's job.
    module Focusable
      private

      def keyboard
        return {} unless drawn?

        {
          tabindex: 0,
          role: "application",
          "aria-label" => label.presence || shadcn_t("chart.label"),
          "data-action" => "keydown->shadcn--chart#navigate blur->shadcn--chart#hide"
        }
      end

      # A chart of nothing has nowhere for a cursor to go, and a tab stop that
      # answers no key is worse than no tab stop.
      def drawn? = raise NotImplementedError, "#{self.class} cannot say whether it drew anything"
    end
  end
end
