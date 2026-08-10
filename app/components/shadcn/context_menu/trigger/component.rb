# frozen_string_literal: true

module Shadcn
  module ContextMenu
    module Trigger
      # The area you right-click. Upstream gives it no classes at all
      # (context-menu.tsx:19) — it is a region, not a control, and what it looks
      # like is the caller's business.
      #
      # A `<span>`, which is Radix's (`Primitive.span`, context-menu.tsx:151) and
      # not a detail: a `<div>` would be block where this is inline, so the same
      # markup would lay out differently. Measured on the live demo before it
      # was believed.
      #
      # `-webkit-touch-callout: none` is Radix's too, and is the only reason a
      # long press on iOS does not raise the system menu over this one.
      #
      # No `aria-haspopup` and no `role`: there is no keyboard route to a
      # context menu, and claiming one would promise something that does not
      # exist. Radix does not add either.
      class Component < ApplicationViewComponent
        default_tag :span
        slot_name :"context-menu-trigger"

        attr_reader :disabled

        def initialize(disabled: false, **attributes)
          @disabled = disabled
          super(**attributes)
        end

        def element_attributes(**defaults)
          attributes = {
            style: merged_style("-webkit-touch-callout: none;"),
            "data-state" => "closed",
            "data-disabled" => (disabled.presence && ""),
            "data-shadcn--dropdown-menu-target" => "trigger"
          }.compact

          # A disabled trigger hands the gesture back to the browser rather than
          # swallowing it, which is Radix's own choice (`:158-161`): a region
          # that does nothing should not also take away the menu you expected.
          attributes["data-action"] = "contextmenu->shadcn--dropdown-menu#openAtPointer" unless disabled

          super(**attributes.merge(defaults))
        end
      end
    end
  end
end
