# frozen_string_literal: true

module Shadcn
  # The parts of the Message family that are just an element with a
  # `data-slot` and a fixed set of classes. Anything with variants, slots or
  # markup of its own keeps its own `component.rb`.
  #
  # Five of the six are exactly that: only `Message` itself computes an
  # attribute, from `align:`.
  module Message
    extend Parts

    part :group, slot: "message-group", classes: "flex min-w-0 flex-col gap-2"

    part :avatar, slot: "message-avatar",
                  classes: "flex w-fit min-w-8 shrink-0 items-center justify-center self-end " \
                           "overflow-hidden rounded-full bg-muted " \
                           "group-has-data-[slot=message-footer]/message:-translate-y-8"

    part :content, slot: "message-content",
                   classes: "flex w-full min-w-0 flex-col gap-2.5 wrap-break-word " \
                            "group-data-[align=end]/message:*:data-slot:self-end"

    part :header, slot: "message-header",
                  classes: "flex max-w-full min-w-0 items-center px-3 text-xs font-medium " \
                           "text-muted-foreground " \
                           "group-has-data-[variant=ghost]/message:px-0"

    part :footer, slot: "message-footer",
                  classes: "flex max-w-full min-w-0 items-center px-3 text-xs font-medium " \
                           "text-muted-foreground " \
                           "group-has-data-[variant=ghost]/message:px-0 " \
                           "group-data-[align=end]/message:justify-end"
  end
end
