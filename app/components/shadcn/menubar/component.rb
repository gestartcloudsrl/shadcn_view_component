# frozen_string_literal: true

module Shadcn
  module Menubar
    # Port of registry/new-york-v4/ui/menubar.tsx — the bar itself.
    #
    # Each menu inside it is a `shadcn--dropdown-menu`, as the context menu's
    # submenus are: what this controller adds is the *bar* — one menu open at a
    # time, arrows moving between the triggers, and a menu already open turning
    # the rest into things you merely hover to reach.
    class Component < ApplicationViewComponent
      slot_name :menubar

      style do
        base { "flex h-9 items-center gap-1 rounded-md border bg-background p-1 shadow-xs" }
      end

      attr_reader :loop

      # Radix's `loop` defaults to **true** here (menubar.tsx:76), unlike the
      # dropdown's, where it is false. A bar is a ring; a list is not.
      def initialize(loop: true, **attributes)
        @loop = loop
        super(**attributes)
      end

      def element_attributes(**defaults)
        super(**{
          role: "menubar",
          "data-controller" => "shadcn--menubar",
          "data-shadcn--menubar-loop-value" => loop
        }.merge(defaults))
      end
    end
  end
end
