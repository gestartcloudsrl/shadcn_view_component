# frozen_string_literal: true

module Shadcn
  # The parts of the AlertDialog family that are just an element with a
  # `data-slot` and a fixed set of classes. Anything with variants, slots or
  # markup of its own keeps its own `component.rb`.
  module AlertDialog
    extend Parts

    part :description, tag: :p, slot: "alert-dialog-description",
                       classes: "text-sm text-muted-foreground"

    part :footer, slot: "alert-dialog-footer",
                  classes: "flex flex-col-reverse gap-2 " \
                           "group-data-[size=sm]/alert-dialog-content:grid " \
                           "group-data-[size=sm]/alert-dialog-content:grid-cols-2 sm:flex-row " \
                           "sm:justify-end"

    part :media, slot: "alert-dialog-media",
                 classes: "mb-2 inline-flex size-16 items-center justify-center rounded-md " \
                          "bg-muted sm:group-data-[size=default]/alert-dialog-content:row-span-2 " \
                          "*:[svg:not([class*='size-'])]:size-8"

    part :overlay, slot: "alert-dialog-overlay", from: Dialog::Overlay::Component

    part :title, tag: :h2, slot: "alert-dialog-title",
                 classes: "text-lg font-semibold " \
                          "sm:group-data-[size=default]/alert-dialog-content:group-has-data-[slot=alert-dialog-media]/alert-dialog-content:col-start-2"

    part :trigger, slot: "alert-dialog-trigger", from: Dialog::Trigger::Component
  end
end
