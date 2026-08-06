# frozen_string_literal: true

module Shadcn
  # The parts of the Card family that are just an element with a
  # `data-slot` and a fixed set of classes. Anything with variants, slots or
  # markup of its own keeps its own `component.rb`.
  module Card
    extend Parts

    part :action, slot: "card-action",
                  classes: "col-start-2 row-span-2 row-start-1 self-start justify-self-end"

    part :content, slot: "card-content", classes: "px-6"

    part :description, slot: "card-description", classes: "text-sm text-muted-foreground"

    part :footer, slot: "card-footer", classes: "flex items-center px-6 [.border-t]:pt-6"

    part :title, slot: "card-title", classes: "leading-none font-semibold"
  end
end
