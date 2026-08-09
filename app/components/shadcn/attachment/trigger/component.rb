# frozen_string_literal: true

module Shadcn
  module Attachment
    module Trigger
      # AttachmentTrigger — a transparent button stretched over the whole
      # attachment, so the card is clickable without nesting a button inside the
      # actions that already sit on top of it (`attachment-actions` carries
      # `z-20` against this one's `z-10`).
      #
      # Its own file for the `type`: upstream sets `type="button"` only when it
      # is really a `<button>`, and leaves it off when `asChild` makes it
      # something else (attachment.tsx:174). `as:` is this gem's `asChild`, so
      # the same condition is `tag_name == :button`.
      class Component < ApplicationViewComponent
        default_tag :button
        slot_name :"attachment-trigger"

        style do
          base { "absolute inset-0 z-10 outline-none" }
        end

        def element_attributes(**defaults)
          return super(**defaults) if tag_name.to_sym != :button

          super(**{ type: "button" }.merge(defaults))
        end
      end
    end
  end
end
