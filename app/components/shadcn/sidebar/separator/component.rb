# frozen_string_literal: true

module Shadcn
  module Sidebar
    module Separator
      # SidebarSeparator — the ported Separator, restamped and tinted to the
      # sidebar's own border colour.
      class Component < Shadcn::Separator::Component
        slot_name :"sidebar-separator"

        EXTRA_CLASSES = "mx-2 w-auto bg-sidebar-border"

        def css_classes(extra = nil)
          super([ EXTRA_CLASSES, extra ].compact.join(" "))
        end

        def element_attributes(**defaults)
          super(**{ "data-sidebar" => "separator" }.merge(defaults))
        end
      end
    end
  end
end
