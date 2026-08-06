# frozen_string_literal: true

module Shadcn
  # The parts of the Sheet family that are just an element with a
  # `data-slot` and a fixed set of classes. Anything with variants, slots or
  # markup of its own keeps its own `component.rb`.
  module Sheet
    extend Parts

    part :close, slot: "sheet-close", from: Dialog::Close::Component

    part :description, tag: :p, slot: "sheet-description", classes: "text-sm text-muted-foreground"

    part :footer, slot: "sheet-footer", classes: "mt-auto flex flex-col gap-2 p-4"

    part :overlay, slot: "sheet-overlay", from: Dialog::Overlay::Component

    part :title, tag: :h2, slot: "sheet-title", classes: "font-semibold text-foreground"

    part :trigger, slot: "sheet-trigger", from: Dialog::Trigger::Component
  end
end
