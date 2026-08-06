# frozen_string_literal: true

module Shadcn
  # The parts of the Alert family that are just an element with a
  # `data-slot` and a fixed set of classes. Anything with variants, slots or
  # markup of its own keeps its own `component.rb`.
  module Alert
    extend Parts

    part :description, slot: "alert-description",
                       classes: "col-start-2 grid justify-items-start gap-1 text-sm " \
                                "text-muted-foreground [&_p]:leading-relaxed"

    part :title, slot: "alert-title",
                 classes: "col-start-2 line-clamp-1 min-h-4 font-medium tracking-tight"
  end
end
