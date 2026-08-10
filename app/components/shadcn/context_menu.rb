# frozen_string_literal: true

module Shadcn
  # The ContextMenu family.
  #
  # Measured against `dropdown-menu.tsx`: the two files declare the same fifteen
  # slots, and eleven of them carry byte-identical class strings once the
  # prefix is normalised. So most of this family *is* the dropdown's, restamped
  # — the same relationship `Sheet` has with `Dialog` here, and the reason both
  # are driven by one controller rather than two.
  #
  # The four that differ: `label` gains `text-foreground`; `content` reads
  # `--radix-context-menu-*` rather than `--radix-dropdown-menu-*`; `sub-trigger`
  # spells the chevron's size through its own `[&_svg…]:size-4` instead of on
  # the icon; and `trigger` is the area you right-click rather than a button.
  module ContextMenu
    extend Parts

    part :label, slot: "context-menu-label",
                 classes: "px-2 py-1.5 text-sm font-medium text-foreground data-[inset]:pl-8"

    part :separator, slot: "context-menu-separator", classes: "-mx-1 my-1 h-px bg-border"

    part :shortcut, tag: :span, slot: "context-menu-shortcut",
                    classes: "ml-auto text-xs tracking-widest text-muted-foreground"

    part :group, slot: "context-menu-group", from: DropdownMenu::Group::Component

    part :radio_group, slot: "context-menu-radio-group",
                       from: DropdownMenu::RadioGroup::Component

    part :item, slot: "context-menu-item", from: DropdownMenu::Item::Component

    part :checkbox_item, slot: "context-menu-checkbox-item",
                         from: DropdownMenu::CheckboxItem::Component

    part :radio_item, slot: "context-menu-radio-item",
                      from: DropdownMenu::RadioItem::Component

    part :sub_trigger, slot: "context-menu-sub-trigger",
                       from: DropdownMenu::SubTrigger::Component
  end
end
