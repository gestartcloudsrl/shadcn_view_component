# frozen_string_literal: true

module Shadcn
  module Combobox
    module Empty
      # Shown when the filter leaves nothing. Upstream shows it with CSS alone —
      # `hidden … group-data-empty/combobox-content:flex` — so the controller
      # only has to put `data-empty` on the content, and this element needs no
      # state of its own.
      class Component < ApplicationViewComponent
        default_tag :div
        slot_name :"combobox-empty"

        style do
          base {
            "hidden w-full justify-center py-2 text-center text-sm text-muted-foreground " \
            "group-data-empty/combobox-content:flex"
          }
        end
      end
    end
  end
end
