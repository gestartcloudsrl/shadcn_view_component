# frozen_string_literal: true

module Shadcn
  # The Menubar family — sixteen slots, and the third built on the dropdown's.
  #
  # Measured against `dropdown-menu.tsx`: eight carry byte-identical class
  # strings once the prefix is normalised, and those are declared with `from:`.
  # The rest differ for real and are written out: the items round to `rounded-xs`
  # where the dropdown rounds to `rounded-sm`, the sub-trigger takes
  # `outline-none` rather than `outline-hidden`, and anything reading a
  # `--radix-*` property reads `--radix-menubar-*`.
  module Menubar
    extend Parts

    part :label, slot: "menubar-label", from: DropdownMenu::Label::Component

    part :separator, slot: "menubar-separator", from: DropdownMenu::Separator::Component

    part :shortcut, slot: "menubar-shortcut", from: DropdownMenu::Shortcut::Component

    part :group, slot: "menubar-group", from: DropdownMenu::Group::Component

    part :radio_group, slot: "menubar-radio-group", from: DropdownMenu::RadioGroup::Component

    part :item, slot: "menubar-item", from: DropdownMenu::Item::Component

    # `rounded-xs`, where the dropdown's are `rounded-sm`. One token, and the
    # only reason these are not `from:` like the rest.
    part :checkbox_item, slot: "menubar-checkbox-item",
                         from: DropdownMenu::CheckboxItem::Component,
                         classes: "relative flex cursor-default items-center gap-2 rounded-xs " \
                                  "py-1.5 pr-2 pl-8 text-sm outline-hidden select-none " \
                                  "focus:bg-accent focus:text-accent-foreground " \
                                  "data-[disabled]:pointer-events-none data-[disabled]:opacity-50 " \
                                  "[&_svg]:pointer-events-none [&_svg]:shrink-0 " \
                                  "[&_svg:not([class*='size-'])]:size-4"

    part :radio_item, slot: "menubar-radio-item",
                      from: DropdownMenu::RadioItem::Component,
                      classes: "relative flex cursor-default items-center gap-2 rounded-xs " \
                               "py-1.5 pr-2 pl-8 text-sm outline-hidden select-none " \
                               "focus:bg-accent focus:text-accent-foreground " \
                               "data-[disabled]:pointer-events-none data-[disabled]:opacity-50 " \
                               "[&_svg]:pointer-events-none [&_svg]:shrink-0 " \
                               "[&_svg:not([class*='size-'])]:size-4"
  end
end
