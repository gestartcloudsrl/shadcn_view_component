# frozen_string_literal: true

module Shadcn
  # The parts of the Dialog family that are just an element with a
  # `data-slot` and a fixed set of classes. Anything with variants, slots or
  # markup of its own keeps its own `component.rb`.
  module Dialog
    extend Parts

    part :description, tag: :p, slot: "dialog-description", classes: "text-sm text-muted-foreground"

    part :footer, slot: "dialog-footer",
                  classes: "flex flex-col-reverse gap-2 sm:flex-row sm:justify-end"

    part :title, tag: :h2, slot: "dialog-title", classes: "text-lg leading-none font-semibold"
  end
end
