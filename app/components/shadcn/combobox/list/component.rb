# frozen_string_literal: true

module Shadcn
  module Combobox
    module List
      # The scrolling part of the panel. `data-empty` is Base UI's, and the
      # empty state's own class reads it through
      # `group-data-empty/combobox-content:flex` — so the attribute lands on the
      # content and the padding rule here reads it too.
      class Component < ApplicationViewComponent
        default_tag :div
        slot_name :"combobox-list"

        style do
          base {
            "max-h-[min(calc(--spacing(96)---spacing(9)),calc(var(--available-height)---spacing(9)))] " \
            "scroll-py-1 overflow-y-auto p-1 data-empty:p-0"
          }
        end

        def element_attributes(**defaults)
          super(**{ "data-shadcn--combobox-target" => "list" }.merge(defaults))
        end
      end
    end
  end
end
