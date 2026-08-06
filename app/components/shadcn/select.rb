# frozen_string_literal: true

module Shadcn
  # The parts of the Select family that are just an element with a
  # `data-slot` and a fixed set of classes. Anything with variants, slots or
  # markup of its own keeps its own `component.rb`.
  module Select
    extend Parts

    part :label, slot: "select-label", classes: "px-2 py-1.5 text-xs text-muted-foreground"

    part :separator, slot: "select-separator",
                     classes: "pointer-events-none -mx-1 my-1 h-px bg-border"
  end
end
