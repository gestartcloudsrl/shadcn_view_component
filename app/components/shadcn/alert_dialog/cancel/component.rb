# frozen_string_literal: true

module Shadcn
  module AlertDialog
    module Cancel
      # AlertDialogCancel — same as Action but outlined by default.
      class Component < Action::Component
        slot_name :"alert-dialog-cancel"

        def initialize(variant: :outline, **attributes)
          super(variant:, **attributes)
        end
      end
    end
  end
end
