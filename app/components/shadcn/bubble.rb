# frozen_string_literal: true

module Shadcn
  # The parts of the Bubble family that are just an element with a
  # `data-slot` and a fixed set of classes. Anything with variants, slots or
  # markup of its own keeps its own `component.rb`.
  module Bubble
    extend Parts

    part :group, slot: "bubble-group", classes: "flex min-w-0 flex-col gap-2"

    # Upstream takes `asChild` here, to make the bubble a button or a link
    # (bubble.tsx:64-71). `as:` answers that everywhere in this gem, so the part
    # needs nothing of its own for it — and the classes below style exactly those
    # two cases.
    part :content, slot: "bubble-content",
                   classes: "w-fit max-w-full min-w-0 overflow-hidden rounded-xl " \
                            "border border-transparent px-3 py-2 text-sm leading-relaxed " \
                            "wrap-break-word group-data-[align=end]/bubble:self-end " \
                            "[button]:text-left [button,a]:transition-colors " \
                            "[button,a]:outline-none [button,a]:focus-visible:border-ring " \
                            "[button,a]:focus-visible:ring-3 [button,a]:focus-visible:ring-ring/50"
  end
end
