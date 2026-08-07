# frozen_string_literal: true

module Shadcn
  module InputGroup
    module Input
      # InputGroupInput renders the ported Input, stripped of its own border and
      # ring so the group's box provides both.
      #
      # Its `data-slot` is `input-group-control`, which it shares with
      # InputGroupTextarea. That is deliberate upstream: the group's
      # `has-[[data-slot=input-group-control]:focus-visible]:…` classes have to
      # match either one, so disambiguating them would break the focus ring.
      class Component < Shadcn::Input::Component
        slot_name :"input-group-control"

        EXTRA_CLASSES = "flex-1 rounded-none border-0 bg-transparent shadow-none " \
                        "focus-visible:ring-0 dark:bg-transparent"

        def css_classes(extra = nil)
          super([ EXTRA_CLASSES, extra ].compact.join(" "))
        end
      end
    end
  end
end
