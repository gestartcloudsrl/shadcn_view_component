# frozen_string_literal: true

module Shadcn
  # The parts of the Pagination family that are just an element with a
  # `data-slot` and a fixed set of classes. Anything with variants, slots or
  # markup of its own keeps its own `component.rb`.
  module Pagination
    extend Parts

    part :content, tag: :ul, slot: "pagination-content", classes: "flex flex-row items-center gap-1"

    part :item, tag: :li, slot: "pagination-item"
  end
end
