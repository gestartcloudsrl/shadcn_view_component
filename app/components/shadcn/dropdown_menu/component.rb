# frozen_string_literal: true

module Shadcn
  module DropdownMenu
    # Port of registry/new-york-v4/ui/dropdown-menu.tsx
    class Component < ApplicationViewComponent
      renders_one :trigger, "Shadcn::DropdownMenu::Trigger::Component"
      renders_one :menu_content, "Shadcn::DropdownMenu::Content::Component"

      slot_name :"dropdown-menu"

      attr_reader :open, :side, :align, :side_offset, :align_offset, :loop

      # `loop` is Radix's own prop, declared on MenuContentImpl and documented
      # `@defaultValue false` (vendor/radix/ui/menu.tsx:363-368). It rides here
      # rather than on Content for the same reason `side` and `align` do: one
      # Stimulus controller owns the whole family, and the root is where it is
      # attached.
      def initialize(open: false, side: :bottom, align: :start, side_offset: 4,
                     align_offset: 0, loop: false, **attributes)
        @open = open
        @side = side&.to_sym || :bottom
        @align = align&.to_sym || :start
        @side_offset = side_offset
        @align_offset = align_offset
        @loop = loop
        super(**attributes)
      end

      def element_attributes(**defaults)
        super(**{
          style: merged_style(CONTENTS_STYLE),
          "data-controller" => "shadcn--dropdown-menu",
          "data-shadcn--dropdown-menu-open-value" => open,
          "data-shadcn--dropdown-menu-side-value" => side,
          "data-shadcn--dropdown-menu-align-value" => align,
          "data-shadcn--dropdown-menu-side-offset-value" => side_offset,
          "data-shadcn--dropdown-menu-align-offset-value" => align_offset,
          "data-shadcn--dropdown-menu-loop-value" => loop
        }.merge(defaults))
      end

      def call
        render_element(body: safe_join([ trigger, menu_content, content ].compact))
      end
    end
  end
end
