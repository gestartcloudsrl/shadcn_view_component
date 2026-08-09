# frozen_string_literal: true

module Shadcn
  # The parts of the Attachment family that are just an element with a
  # `data-slot` and a fixed set of classes. Anything with variants, slots or
  # markup of its own keeps its own `component.rb`.
  #
  # `attachment-group` and `attachment-title` reach for three utilities that are
  # shadcn's own CSS rather than Tailwind's — `scroll-fade-x`, `scrollbar-none`
  # and `shimmer`. They are defined in `shadcn.css`; see the comment there for
  # where they were read from and what could not be checked.
  module Attachment
    extend Parts

    part :group, slot: "attachment-group",
                 classes: "flex min-w-0 scroll-fade-x snap-x snap-mandatory scroll-px-1 " \
                          "scrollbar-none gap-3 overflow-x-auto overscroll-x-contain py-1 " \
                          "*:data-[slot=attachment]:flex-none " \
                          "*:data-[slot=attachment]:snap-start"

    part :content, slot: "attachment-content",
                   classes: "max-w-full min-w-0 flex-1 leading-tight " \
                            "group-data-[orientation=vertical]/attachment:px-1"

    part :title, slot: "attachment-title", tag: :span,
                 classes: "block max-w-full min-w-0 truncate font-medium " \
                          "group-data-[state=processing]/attachment:shimmer " \
                          "group-data-[state=uploading]/attachment:shimmer"

    part :description, slot: "attachment-description", tag: :span,
                       classes: "mt-0.5 block min-w-0 truncate text-xs text-muted-foreground " \
                                "group-data-[state=error]/attachment:text-destructive/80 " \
                                "max-w-full"

    part :actions, slot: "attachment-actions",
                   classes: "relative z-20 flex shrink-0 items-center " \
                            "group-data-[orientation=vertical]/attachment:absolute " \
                            "group-data-[orientation=vertical]/attachment:top-3 " \
                            "group-data-[orientation=vertical]/attachment:right-3 " \
                            "group-data-[orientation=vertical]/attachment:gap-1"
  end
end
