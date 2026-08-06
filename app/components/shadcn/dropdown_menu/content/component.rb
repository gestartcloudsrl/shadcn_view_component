# frozen_string_literal: true

module Shadcn
  module DropdownMenu
    module Content
      # DropdownMenuContent
      class Component < ApplicationViewComponent
        renders_many :items, "Shadcn::DropdownMenu::Item::Component"

        slot_name :"dropdown-menu-content"

        style do
          base {
            "z-50 max-h-(--radix-dropdown-menu-content-available-height) min-w-[8rem] " \
            "origin-(--radix-dropdown-menu-content-transform-origin) overflow-x-hidden " \
            "overflow-y-auto rounded-md border bg-popover p-1 text-popover-foreground " \
            "shadow-md data-[side=bottom]:slide-in-from-top-2 " \
            "data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 " \
            "data-[side=top]:slide-in-from-bottom-2 data-[state=closed]:animate-out " \
            "data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 " \
            "data-[state=open]:animate-in data-[state=open]:fade-in-0 " \
            "data-[state=open]:zoom-in-95"
          }
        end

        def element_attributes(**defaults)
          super(**{
            role: "menu",
            tabindex: "-1",
            "aria-orientation" => "vertical",
            "data-state" => "closed",
            hidden: true,
            "data-shadcn--dropdown-menu-target" => "content",
            "data-action" => "keydown->shadcn--dropdown-menu#contentKeydown"
          }.merge(defaults))
        end

        # shadcn wraps the content in a DropdownMenuPortal. Radix relocates it to
        # `document.body`; here it stays put (see the Stimulus controller for
        # why) and is `display: contents`, so it adds no box of its own.
        def call
          tag.div("data-slot": "dropdown-menu-portal", style: CONTENTS_STYLE) do
            render_element(body: safe_join([ items, content ].flatten.compact))
          end
        end
      end
    end
  end
end
