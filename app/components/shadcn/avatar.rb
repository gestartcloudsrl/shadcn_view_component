# frozen_string_literal: true

module Shadcn
  # The parts of the Avatar family that are just an element with a
  # `data-slot` and a fixed set of classes. Anything with variants, slots or
  # markup of its own keeps its own `component.rb`.
  module Avatar
    extend Parts

    part :badge, tag: :span, slot: "avatar-badge",
                 classes: "absolute right-0 bottom-0 z-10 inline-flex items-center justify-center " \
                          "rounded-full bg-primary text-primary-foreground ring-2 ring-background " \
                          "select-none group-data-[size=sm]/avatar:size-2 " \
                          "group-data-[size=sm]/avatar:[&>svg]:hidden " \
                          "group-data-[size=default]/avatar:size-2.5 " \
                          "group-data-[size=default]/avatar:[&>svg]:size-2 " \
                          "group-data-[size=lg]/avatar:size-3 " \
                          "group-data-[size=lg]/avatar:[&>svg]:size-2"

    part :group, slot: "avatar-group",
                 classes: "group/avatar-group flex -space-x-2 *:data-[slot=avatar]:ring-2 " \
                          "*:data-[slot=avatar]:ring-background"

    part :group_count, slot: "avatar-group-count",
                       classes: "relative flex size-8 shrink-0 items-center justify-center " \
                                "rounded-full bg-muted text-sm text-muted-foreground ring-2 " \
                                "ring-background group-has-data-[size=lg]/avatar-group:size-10 " \
                                "group-has-data-[size=sm]/avatar-group:size-6 [&>svg]:size-4 " \
                                "group-has-data-[size=lg]/avatar-group:[&>svg]:size-5 " \
                                "group-has-data-[size=sm]/avatar-group:[&>svg]:size-3"
  end
end
