# frozen_string_literal: true

module Shadcn
  # The parts of the Command family that are an element with a `data-slot` and
  # fixed classes. Everything else — the root, the input, the list, the group,
  # the item, the separator and the dialog — carries an attribute `part` cannot
  # express, mostly `cmdk-*` and a role.
  module Command
    extend Parts

    part :shortcut, slot: "command-shortcut", tag: :span,
                    classes: "ml-auto text-xs tracking-widest text-muted-foreground"
  end
end
