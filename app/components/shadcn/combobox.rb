# frozen_string_literal: true

module Shadcn
  # The parts of the Combobox family that are an element with a `data-slot` and
  # fixed classes.
  module Combobox
    extend Parts

    part :value, slot: "combobox-value", tag: :span
    part :group, slot: "combobox-group"
    part :label, slot: "combobox-label",
                 classes: "px-2 py-1.5 text-xs text-muted-foreground pointer-coarse:px-3 " \
                          "pointer-coarse:py-2 pointer-coarse:text-sm"
    part :separator, slot: "combobox-separator", classes: "-mx-1 my-1 h-px bg-border"
  end
end
