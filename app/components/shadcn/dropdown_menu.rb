# frozen_string_literal: true

module Shadcn
  # The parts of the DropdownMenu family that are just an element with a
  # `data-slot` and a fixed set of classes. Anything with variants, slots or
  # markup of its own keeps its own `component.rb`.
  module DropdownMenu
    extend Parts

    part :label, slot: "dropdown-menu-label",
                 classes: "px-2 py-1.5 text-sm font-medium data-[inset]:pl-8"

    part :separator, slot: "dropdown-menu-separator", classes: "-mx-1 my-1 h-px bg-border"

    part :shortcut, tag: :span, slot: "dropdown-menu-shortcut",
                    classes: "ml-auto text-xs tracking-widest text-muted-foreground"
  end
end
