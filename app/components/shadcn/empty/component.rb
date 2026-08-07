# frozen_string_literal: true

module Shadcn
  module Empty
    # Port of registry/new-york-v4/ui/empty.tsx
    class Component < ApplicationViewComponent
      slot_name :empty

      style do
        base {
          "flex min-w-0 flex-1 flex-col items-center justify-center gap-6 rounded-lg " \
          "border-dashed p-6 text-center text-balance md:p-12"
        }
      end
    end
  end
end
