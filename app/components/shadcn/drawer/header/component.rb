# frozen_string_literal: true

module Shadcn
  module Drawer
    module Header
      # DrawerHeader — a slot for the title and the description, as the Sheet's
      # and the Dialog's are.
      #
      # The two `group-data-*` classes read the direction off the *content*,
      # which is why that attribute lives there rather than on the root shadcn
      # takes it on: a header centres itself only when the drawer comes from an
      # edge that makes it the top of the panel.
      class Component < ApplicationViewComponent
        renders_one :title, "Shadcn::Drawer::Title::Component"
        renders_one :description, "Shadcn::Drawer::Description::Component"

        slot_name :"drawer-header"

        style do
          base {
            "flex flex-col gap-0.5 p-4 " \
            "group-data-[vaul-drawer-direction=bottom]/drawer-content:text-center " \
            "group-data-[vaul-drawer-direction=top]/drawer-content:text-center " \
            "md:gap-1.5 md:text-left"
          }
        end

        def call
          render_element(body: safe_join([ title, description, content ].compact))
        end
      end
    end
  end
end
