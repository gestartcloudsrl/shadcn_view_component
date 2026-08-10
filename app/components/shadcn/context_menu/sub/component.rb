# frozen_string_literal: true

module Shadcn
  module ContextMenu
    module Sub
      # A nested menu. Written out rather than subclassed: ViewComponent refuses
      # to redeclare an inherited slot, and this one has to hold *this* family's
      # sub-content — which differs from the dropdown's in the only way that
      # matters here, the `--radix-*` properties it reads.
      #
      # Another `shadcn--dropdown-menu` controller, carrying the prefix so
      # `popper.js` writes the properties that content looks for.
      class Component < ApplicationViewComponent
        renders_one :trigger, "Shadcn::ContextMenu::SubTrigger::Component"
        renders_one :menu_content, "Shadcn::ContextMenu::SubContent::Component"

        slot_name :"context-menu-sub"

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
            "data-shadcn--dropdown-menu-prefix-value" => "context-menu",
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
