# frozen_string_literal: true

module Shadcn
  module Menubar
    module Menu
      # One menu in the bar: its trigger and its panel. Upstream gives it no
      # classes (menubar.tsx:28) — it is a grouping, not a box.
      #
      # A `shadcn--dropdown-menu` of its own, carrying the prefix so `popper.js`
      # writes the `--radix-menubar-*` properties the panel reads.
      class Component < ApplicationViewComponent
        renders_one :trigger, "Shadcn::Menubar::Trigger::Component"
        renders_one :menu_content, "Shadcn::Menubar::Content::Component"

        slot_name :"menubar-menu"

        def element_attributes(**defaults)
          super(**{
            style: merged_style(CONTENTS_STYLE),
            "data-controller" => "shadcn--dropdown-menu",
            "data-shadcn--dropdown-menu-prefix-value" => "menubar",
            "data-shadcn--menubar-target" => "menu",
            # Upstream's own defaults for a menubar panel (menubar.tsx:68-70):
            # it hangs below the bar, aligned to its trigger's left edge and
            # pulled back by the bar's own padding.
            "data-shadcn--dropdown-menu-side-value" => "bottom",
            "data-shadcn--dropdown-menu-align-value" => "start",
            "data-shadcn--dropdown-menu-side-offset-value" => 8,
            "data-shadcn--dropdown-menu-align-offset-value" => -4
          }.merge(defaults))
        end

        def call
          render_element(body: safe_join([ trigger, menu_content, content ].compact))
        end
      end
    end
  end
end
