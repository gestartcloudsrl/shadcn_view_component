# frozen_string_literal: true

module Shadcn
  module InputGroup
    module Textarea
      # InputGroupTextarea renders the ported Textarea, and shares
      # `data-slot="input-group-control"` with InputGroupInput — see that file
      # for why the two must not be told apart.
      class Component < Shadcn::Textarea::Component
        slot_name :"input-group-control"

        EXTRA_CLASSES = "flex-1 resize-none rounded-none border-0 bg-transparent py-3 " \
                        "shadow-none focus-visible:ring-0 dark:bg-transparent"

        def css_classes(extra = nil)
          super([ EXTRA_CLASSES, extra ].compact.join(" "))
        end
      end
    end
  end
end
