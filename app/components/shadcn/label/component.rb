# frozen_string_literal: true

module Shadcn
  module Label
    # Port of registry/new-york-v4/ui/label.tsx
    class Component < ApplicationViewComponent
      default_tag :label
      slot_name :label

      style do
        base {
          "flex items-center gap-2 text-sm leading-none font-medium select-none " \
          "group-data-[disabled=true]:pointer-events-none " \
          "group-data-[disabled=true]:opacity-50 peer-disabled:cursor-not-allowed " \
          "peer-disabled:opacity-50"
        }
      end
    end
  end
end
