# frozen_string_literal: true

module Shadcn
  # The parts of the Empty family that are just an element with a `data-slot`
  # and a fixed set of classes. `EmptyMedia` has a variant, so it keeps its own
  # `component.rb`.
  #
  # `EmptyDescription` is typed `React.ComponentProps<"p">` upstream but renders
  # a `<div>`. The element is what the port follows.
  module Empty
    extend Parts

    part :header, slot: "empty-header",
                  classes: "flex max-w-sm flex-col items-center gap-2 text-center"

    part :title, slot: "empty-title", classes: "text-lg font-medium tracking-tight"

    part :description, slot: "empty-description",
                       classes: "text-sm/relaxed text-muted-foreground [&>a]:underline " \
                                "[&>a]:underline-offset-4 [&>a:hover]:text-primary"

    part :content, slot: "empty-content",
                   classes: "flex w-full max-w-sm min-w-0 flex-col items-center gap-4 " \
                            "text-sm text-balance"
  end
end
