# frozen_string_literal: true

module Shadcn
  module Message
    # Port of registry/new-york-v4/ui/message.tsx
    #
    # `align:` is not a cva variant upstream — the classes are one string and the
    # side is chosen by `data-[align=end]:flex-row-reverse` reading the attribute
    # this writes (message.tsx:23-26). Its own file all the same, because a
    # computed attribute is exactly what `part` does not do.
    class Component < ApplicationViewComponent
      slot_name :message

      style do
        base {
          "group/message relative flex w-full min-w-0 gap-2 text-sm " \
          "data-[align=end]:flex-row-reverse"
        }
      end

      attr_reader :align

      def initialize(align: :start, **attributes)
        @align = align&.to_sym || :start
        super(**attributes)
      end

      def element_attributes(**defaults)
        super(**{ "data-align" => align }.merge(defaults))
      end
    end
  end
end
