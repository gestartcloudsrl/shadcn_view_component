# frozen_string_literal: true

module Shadcn
  # The one part of the ScrollArea family that is an element with a `data-slot`
  # and fixed classes.
  module ScrollArea
    extend Parts

    # Radix's `ScrollAreaThumb`. Its width, height and transform are inline and
    # the controller's — the classes only make it a rounded bar.
    part :thumb, slot: "scroll-area-thumb",
                 classes: "relative flex-1 rounded-full bg-border"
  end
end
