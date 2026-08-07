# frozen_string_literal: true

module Shadcn
  # The parts of the Item family that are just an element with a `data-slot`
  # and a fixed set of classes. `Item`, `ItemGroup`, `ItemMedia` and
  # `ItemSeparator` each need more than that, so they keep their own
  # `component.rb`.
  #
  # `ItemDescription` really is a `<p>` here — unlike Empty's, which upstream
  # types as `"p"` while rendering a `<div>`.
  module Item
    extend Parts

    part :content, slot: "item-content",
                   classes: "flex flex-1 flex-col gap-1 " \
                            "[&+[data-slot=item-content]]:flex-none"

    part :title, slot: "item-title",
                 classes: "flex w-fit items-center gap-2 text-sm leading-snug font-medium"

    part :description, slot: "item-description", tag: :p,
                       classes: "line-clamp-2 text-sm leading-normal font-normal " \
                                "text-balance text-muted-foreground [&>a]:underline " \
                                "[&>a]:underline-offset-4 [&>a:hover]:text-primary"

    part :actions, slot: "item-actions", classes: "flex items-center gap-2"

    part :header, slot: "item-header",
                  classes: "flex basis-full items-center justify-between gap-2"

    part :footer, slot: "item-footer",
                  classes: "flex basis-full items-center justify-between gap-2"
  end
end
