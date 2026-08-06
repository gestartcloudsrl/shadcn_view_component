# frozen_string_literal: true

module Shadcn
  module Popover
    module Content
      # PopoverContent
      class Component < ApplicationViewComponent
        renders_one :header, "Shadcn::Popover::Header::Component"

        slot_name :"popover-content"

        style do
          base {
            "z-50 w-72 origin-(--radix-popover-content-transform-origin) rounded-md border " \
            "bg-popover p-4 text-popover-foreground shadow-md outline-hidden " \
            "data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 " \
            "data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 " \
            "data-[state=closed]:animate-out data-[state=closed]:fade-out-0 " \
            "data-[state=closed]:zoom-out-95 data-[state=open]:animate-in " \
            "data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95"
          }
        end

        def element_attributes(**defaults)
          super(**{
            role: "dialog",
            tabindex: "-1",
            "data-state" => "closed",
            hidden: true,
            "data-shadcn--popover-target" => "content"
          }.merge(defaults))
        end

        def call
          render_element(body: safe_join([ header, content ].compact))
        end
      end
    end
  end
end
