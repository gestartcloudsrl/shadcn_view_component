# frozen_string_literal: true

module Shadcn
  module Dialog
    # Port of registry/new-york-v4/ui/dialog.tsx
    #
    # Radix's Dialog.Root is a context provider and renders no DOM. Stimulus
    # needs an element to attach to, so the root is a `display: contents`
    # wrapper — invisible to layout, and it gives shadcn's `data-slot="dialog"`
    # somewhere to live.
    class Component < ApplicationViewComponent
      include Concerns::ModalRoot

      renders_one :trigger, "Shadcn::Dialog::Trigger::Component"
      renders_one :dialog_content, "Shadcn::Dialog::Content::Component"

      slot_name :dialog
    end
  end
end
