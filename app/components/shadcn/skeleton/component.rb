# frozen_string_literal: true

module Shadcn
  module Skeleton
    # Port of registry/new-york-v4/ui/skeleton.tsx
    class Component < ApplicationViewComponent
      slot_name :skeleton

      style do
        base { "animate-pulse rounded-md bg-accent" }
      end
    end
  end
end
