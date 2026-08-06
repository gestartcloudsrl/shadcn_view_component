# frozen_string_literal: true

module Shadcn
  module DropdownMenu
    module Sub
      # DropdownMenuSub — a nested menu.
      #
      # It is another `shadcn--dropdown-menu` controller, anchored to the right
      # of its trigger. Stimulus scopes targets to the nearest controller of the
      # same identifier, so the parent menu's items and the submenu's stay apart.
      class Component < ApplicationViewComponent
        renders_one :trigger, "Shadcn::DropdownMenu::SubTrigger::Component"
        renders_one :menu_content, "Shadcn::DropdownMenu::SubContent::Component"

        slot_name :"dropdown-menu-sub"

        attr_reader :open, :side, :align, :side_offset

        def initialize(open: false, side: :right, align: :start, side_offset: 0, **attributes)
          @open = open
          @side = side&.to_sym || :right
          @align = align&.to_sym || :start
          @side_offset = side_offset
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{
            style: merged_style(CONTENTS_STYLE),
            "data-controller" => "shadcn--dropdown-menu",
            "data-shadcn--dropdown-menu-open-value" => open,
            "data-shadcn--dropdown-menu-side-value" => side,
            "data-shadcn--dropdown-menu-align-value" => align,
            "data-shadcn--dropdown-menu-side-offset-value" => side_offset
          }.merge(defaults))
        end

        def call
          render_element(body: safe_join([ trigger, menu_content, content ].compact))
        end
      end
    end
  end
end
