# frozen_string_literal: true

module Shadcn
  module AlertDialog
    # Port of registry/new-york-v4/ui/alert-dialog.tsx
    #
    # Same primitive as Dialog, except Radix deliberately refuses to close an
    # alert dialog on an outside click — the user has to pick an action.
    class Component < ApplicationViewComponent
      include Concerns::ModalRoot

      renders_one :trigger, "Shadcn::AlertDialog::Trigger::Component"
      renders_one :dialog_content, "Shadcn::AlertDialog::Content::Component"

      slot_name :"alert-dialog"

      def dismissable? = false
    end
  end
end
