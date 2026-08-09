# frozen_string_literal: true

module Shadcn
  module Sidebar
    module Trigger
      # SidebarTrigger — upstream renders a ghost icon Button
      # (vendor/shadcn/ui/sidebar.tsx:256-280), so this borrows the button's own
      # compiled variants rather than restating them, as PaginationLink does.
      class Component < ApplicationViewComponent
        default_tag :button
        slot_name :"sidebar-trigger"

        def element_attributes(**defaults)
          super(**{
            type: "button",
            "data-sidebar" => "trigger",
            "data-shadcn--sidebar-target" => "trigger",
            "data-action" => "click->shadcn--sidebar#toggle"
          }.merge(defaults))
        end

        def css_classes(extra = nil)
          Button::Component.variant_classes(variant: :ghost, size: :icon, class: [ "size-7", extra ].compact.join(" "))
        end

        # The label is `sr-only` rather than an `aria-label`: upstream puts it in
        # the button's content, and a visible-to-screen-readers span survives
        # translation tooling that an attribute does not.
        def call
          render_element(body: safe_join([
            render(Icon::Component.new("panel-left")),
            tag.span(shadcn_t("sidebar.toggle"), class: "sr-only"),
            content
          ].compact))
        end
      end
    end
  end
end
