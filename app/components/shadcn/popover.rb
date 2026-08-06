# frozen_string_literal: true

module Shadcn
  # The parts of the Popover family that are just an element with a
  # `data-slot` and a fixed set of classes. Anything with variants, slots or
  # markup of its own keeps its own `component.rb`.
  module Popover
    extend Parts

    part :description, tag: :p, slot: "popover-description", classes: "text-muted-foreground"

    part :header, slot: "popover-header", classes: "flex flex-col gap-1 text-sm"

    part :title, slot: "popover-title", classes: "font-medium"
  end
end
