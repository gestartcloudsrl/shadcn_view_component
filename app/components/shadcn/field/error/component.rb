# frozen_string_literal: true

module Shadcn
  module Field
    module Error
      # FieldError — renders nothing when there is neither content nor errors.
      # A single error is inlined; several are listed, like the TSX does.
      class Component < ApplicationViewComponent
        LIST_CLASSES = "ml-4 flex list-disc flex-col gap-1"

        slot_name :"field-error"

        style do
          base { "text-sm font-normal text-destructive" }
        end

        attr_reader :errors

        def initialize(errors: [], **attributes)
          @errors = Array(errors).compact.map(&:to_s).uniq
          super(**attributes)
        end

        def render?
          content.present? || errors.any?
        end

        def element_attributes(**defaults)
          super(**{ role: "alert" }.merge(defaults))
        end

        def call
          render_element(body: body)
        end

        private

        def body
          return content if content.present?
          return errors.first if errors.one?

          tag.ul(class: LIST_CLASSES) do
            safe_join(errors.map { |message| tag.li(message) })
          end
        end
      end
    end
  end
end
