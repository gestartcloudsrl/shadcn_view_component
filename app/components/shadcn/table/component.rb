# frozen_string_literal: true

module Shadcn
  module Table
    # Port of registry/new-york-v4/ui/table.tsx
    #
    # shadcn always wraps the table in a scroll container carrying
    # `data-slot="table-container"`.
    class Component < ApplicationViewComponent
      CONTAINER_CLASSES = "relative w-full overflow-x-auto"

      default_tag :table
      slot_name :table

      style do
        base { "w-full caption-bottom text-sm" }
      end

      def call
        tag.div("data-slot": "table-container", class: CONTAINER_CLASSES) do
          render_element(body: content)
        end
      end
    end
  end
end
