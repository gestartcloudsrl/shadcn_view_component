# frozen_string_literal: true

module Shadcn
  # The parts of the Breadcrumb family that are just an element with a
  # `data-slot` and a fixed set of classes. Anything with variants, slots or
  # markup of its own keeps its own `component.rb`.
  module Breadcrumb
    extend Parts

    part :item, tag: :li, slot: "breadcrumb-item", classes: "inline-flex items-center gap-1.5"

    part :link, tag: :a, slot: "breadcrumb-link", classes: "transition-colors hover:text-foreground"

    part :list, tag: :ol, slot: "breadcrumb-list",
                classes: "flex flex-wrap items-center gap-1.5 text-sm break-words " \
                         "text-muted-foreground sm:gap-2.5"
  end
end
