# frozen_string_literal: true

module Shadcn
  # The parts of the Marker family that are just an element with a
  # `data-slot` and a fixed set of classes. Anything with variants, slots or
  # markup of its own keeps its own `component.rb`.
  module Marker
    extend Parts

    part :content, slot: "marker-content", tag: :span,
                   classes: "min-w-0 wrap-break-word " \
                            "group-data-[variant=separator]/marker:flex-none " \
                            "group-data-[variant=separator]/marker:text-center " \
                            "*:[a]:underline *:[a]:underline-offset-3 " \
                            "*:[a]:hover:text-foreground"
  end
end
