# frozen_string_literal: true

module Shadcn
  module InputGroup
    module Text
      # InputGroupText. A `<span>`, and like ButtonGroupText it carries no
      # `data-slot` upstream, so it is not given one here.
      class Component < ApplicationViewComponent
        default_tag :span

        style do
          base {
            "flex items-center gap-2 text-sm text-muted-foreground " \
            "[&_svg]:pointer-events-none [&_svg:not([class*='size-'])]:size-4"
          }
        end
      end
    end
  end
end
