# frozen_string_literal: true

module Shadcn
  module Avatar
    module Fallback
      class Component < ApplicationViewComponent
        default_tag :span
        slot_name :"avatar-fallback"

        style do
          base {
            "flex size-full items-center justify-center rounded-full bg-muted text-sm " \
            "text-muted-foreground group-data-[size=sm]/avatar:text-xs"
          }
        end

        def element_attributes(**defaults)
          super(**{ "data-shadcn--avatar-target" => "fallback" }.merge(defaults))
        end
      end
    end
  end
end
