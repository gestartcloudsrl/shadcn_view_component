# frozen_string_literal: true

module Shadcn
  # The parts of the NativeSelect family that are just an element with a
  # `data-slot` and a fixed set of classes. Anything with variants, slots or
  # markup of its own keeps its own `component.rb`.
  module NativeSelect
    extend Parts

    part :opt_group, tag: :optgroup, slot: "native-select-optgroup",
                     classes: "bg-[Canvas] text-[CanvasText]"

    part :option, tag: :option, slot: "native-select-option",
                  classes: "bg-[Canvas] text-[CanvasText]"
  end
end
