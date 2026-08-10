# frozen_string_literal: true

module Shadcn
  module ContextMenu
    # Port of registry/new-york-v4/ui/context-menu.tsx.
    #
    # Driven by `shadcn--dropdown-menu`, not a controller of its own: the two
    # families declare the same slots and the menu's whole behaviour once open
    # — roving focus, typeahead, submenus, checkbox and radio items — is the
    # dropdown's. What differs is the way in, which is one action and one value.
    class Component < ApplicationViewComponent
      renders_one :trigger, "Shadcn::ContextMenu::Trigger::Component"
      renders_one :menu_content, "Shadcn::ContextMenu::Content::Component"

      slot_name :"context-menu"

      attr_reader :loop

      # `loop:` is the dropdown's own addition, kept here because both share the
      # controller — Radix has it as a prop and shadcn passes it in neither file.
      def initialize(loop: false, **attributes)
        @loop = loop
        super(**attributes)
      end

      def element_attributes(**defaults)
        super(**{
          style: merged_style(CONTENTS_STYLE),
          "data-controller" => "shadcn--dropdown-menu",
          "data-shadcn--dropdown-menu-prefix-value" => "context-menu",
          "data-shadcn--dropdown-menu-loop-value" => loop,
          # A context menu opens where the pointer is, so it has no side to
          # prefer and no gap to leave: the point *is* the corner.
          "data-shadcn--dropdown-menu-side-value" => "bottom",
          "data-shadcn--dropdown-menu-align-value" => "start",
          "data-shadcn--dropdown-menu-side-offset-value" => 0
        }.merge(defaults))
      end

      def call
        render_element(body: safe_join([ trigger, menu_content, content ].compact))
      end
    end
  end
end
