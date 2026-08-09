# frozen_string_literal: true

module Shadcn
  module Attachment
    module Action
      # AttachmentAction — a Button with two different defaults, which is all
      # upstream changes about it (attachment.tsx:144-159). Subclassed rather
      # than declared with `part … from:`, because that restamps the slot and
      # leaves the arguments alone, and these are arguments.
      class Component < Button::Component
        slot_name :"attachment-action"

        def initialize(variant: :ghost, size: :"icon-xs", **attributes)
          super
        end
      end
    end
  end
end
