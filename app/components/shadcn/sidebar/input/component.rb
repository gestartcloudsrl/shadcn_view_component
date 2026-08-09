# frozen_string_literal: true

module Shadcn
  module Sidebar
    module Input
      # SidebarInput — the ported Input under another `data-slot`, with the
      # sidebar's own sizing on top. Inherit-and-restamp, as ButtonGroupSeparator
      # does to Separator, so the parent's classes are not restated and cannot
      # rot.
      class Component < Shadcn::Input::Component
        slot_name :"sidebar-input"

        EXTRA_CLASSES = "h-8 w-full bg-background shadow-none"

        def css_classes(extra = nil)
          super([ EXTRA_CLASSES, extra ].compact.join(" "))
        end

        def element_attributes(**defaults)
          super(**{ "data-sidebar" => "input" }.merge(defaults))
        end
      end
    end
  end
end
