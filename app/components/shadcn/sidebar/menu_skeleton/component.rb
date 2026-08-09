# frozen_string_literal: true

module Shadcn
  module Sidebar
    module MenuSkeleton
      # SidebarMenuSkeleton — a placeholder row. Upstream randomises the text
      # width between 50% and 90% so a column of them does not look like a
      # barcode (vendor/shadcn/ui/sidebar.tsx:611-613); the same range is used
      # here, drawn once per instance.
      class Component < ApplicationViewComponent
        slot_name :"sidebar-menu-skeleton"

        style do
          base { "flex h-8 items-center gap-2 rounded-md px-2" }
        end

        attr_reader :show_icon

        def initialize(show_icon: false, **attributes)
          @show_icon = show_icon
          @width = "#{rand(50..89)}%"
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{ "data-sidebar" => "menu-skeleton" }.merge(defaults))
        end

        def call
          render_element(body: safe_join([ icon, text ].compact))
        end

        private

        def icon
          return unless show_icon

          render(Skeleton::Component.new(class: "size-4 rounded-md", "data-sidebar": "menu-skeleton-icon"))
        end

        def text
          render(Skeleton::Component.new(
                   class: "h-4 max-w-(--skeleton-width) flex-1",
                   "data-sidebar": "menu-skeleton-text",
                   style: "--skeleton-width: #{@width};"
                 ))
        end
      end
    end
  end
end
