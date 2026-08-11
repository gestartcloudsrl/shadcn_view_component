# frozen_string_literal: true

module Shadcn
  # The parts of the Drawer family that are just an element with a `data-slot`
  # and a fixed set of classes. Anything with variants, slots or markup of its
  # own keeps its own `component.rb`.
  #
  # Upstream builds this on **vaul**, not on Radix — but vaul is itself a Radix
  # Dialog with a drag on top (`import * as DialogPrimitive from
  # '@radix-ui/react-dialog'` is its third line), so the parts that are only
  # markup come from the Dialog here for the same reason the Sheet's do.
  module Drawer
    extend Parts

    part :close, slot: "drawer-close", from: Dialog::Close::Component

    part :description, tag: :p, slot: "drawer-description", classes: "text-sm text-muted-foreground"

    part :footer, slot: "drawer-footer", classes: "mt-auto flex flex-col gap-2 p-4"

    part :overlay, slot: "drawer-overlay", from: Dialog::Overlay::Component

    part :title, tag: :h2, slot: "drawer-title", classes: "font-semibold text-foreground"

    part :trigger, slot: "drawer-trigger", from: Dialog::Trigger::Component
  end
end
