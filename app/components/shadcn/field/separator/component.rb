# frozen_string_literal: true

module Shadcn
  module Field
    module Separator
      # FieldSeparator — a rule with optional centred content.
      class Component < ApplicationViewComponent
        CONTENT_CLASSES = "relative mx-auto block w-fit bg-background px-2 text-muted-foreground"

        slot_name :"field-separator"

        style do
          base {
            "relative -my-2 h-5 text-sm group-data-[variant=outline]/field-group:-mb-2"
          }
        end

        def element_attributes(**defaults)
          super(**{ "data-content" => content.present? }.merge(defaults))
        end

        def call
          body = [ render(Shadcn::Separator::Component.new(class: "absolute inset-0 top-1/2")) ]

          if content.present?
            body << tag.span(content, class: CONTENT_CLASSES,
                                      "data-slot": "field-separator-content")
          end

          render_element(body: safe_join(body))
        end
      end
    end
  end
end
