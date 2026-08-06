# frozen_string_literal: true

module Shadcn
  # The parts of the Table family that are just an element with a
  # `data-slot` and a fixed set of classes. Anything with variants, slots or
  # markup of its own keeps its own `component.rb`.
  module Table
    extend Parts

    part :body, tag: :tbody, slot: "table-body", classes: "[&_tr:last-child]:border-0"

    part :caption, tag: :caption, slot: "table-caption",
                   classes: "mt-4 text-sm text-muted-foreground"

    part :cell, tag: :td, slot: "table-cell",
                classes: "p-2 align-middle whitespace-nowrap [&:has([role=checkbox])]:pr-0 " \
                         "[&>[role=checkbox]]:translate-y-[2px]"

    part :footer, tag: :tfoot, slot: "table-footer",
                  classes: "border-t bg-muted/50 font-medium [&>tr]:last:border-b-0"

    part :head, tag: :th, slot: "table-head",
                classes: "h-10 px-2 text-left align-middle font-medium whitespace-nowrap " \
                         "text-foreground [&:has([role=checkbox])]:pr-0 " \
                         "[&>[role=checkbox]]:translate-y-[2px]"

    part :header, tag: :thead, slot: "table-header", classes: "[&_tr]:border-b"

    part :row, tag: :tr, slot: "table-row",
               classes: "border-b transition-colors hover:bg-muted/50 " \
                        "has-aria-expanded:bg-muted/50 data-[state=selected]:bg-muted"
  end
end
