# frozen_string_literal: true

module Shadcn
  module Command
    module Group
      # A titled run of items. cmdk renders three elements — the group, an
      # `aria-hidden` heading and a `role="group"` wrapper named by it
      # (`vendor/cmdk/index.tsx:750-764`) — and shadcn's classes select the
      # middle one by `[cmdk-group-heading]`, so all three are reproduced.
      #
      # The whole group hides when every item in it is filtered away, which is
      # the controller's job and the reason `hidden` is not a caller's argument.
      class Component < ApplicationViewComponent
        default_tag :div
        slot_name :"command-group"

        style do
          base {
            "overflow-hidden p-1 text-foreground [&_[cmdk-group-heading]]:px-2 " \
            "[&_[cmdk-group-heading]]:py-1.5 [&_[cmdk-group-heading]]:text-xs " \
            "[&_[cmdk-group-heading]]:font-medium [&_[cmdk-group-heading]]:text-muted-foreground"
          }
        end

        attr_reader :heading

        def initialize(heading: nil, **attributes)
          @heading = heading
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{
            "cmdk-group" => "",
            role: "presentation",
            "data-shadcn--command-target" => "group"
          }.merge(defaults))
        end

        def call
          render_element(body: safe_join([ title, items ].compact))
        end

        private

        def heading_id
          @heading_id ||= "shadcn-command-heading-#{SecureRandom.hex(4)}"
        end

        def title
          return unless heading.present?

          tag.div(heading, id: heading_id, "cmdk-group-heading": "", "aria-hidden": "true")
        end

        def items
          tag.div(content, "cmdk-group-items": "", role: "group",
                  "aria-labelledby": (heading_id if heading.present?))
        end
      end
    end
  end
end
