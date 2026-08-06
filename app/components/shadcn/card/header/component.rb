# frozen_string_literal: true

module Shadcn
  module Card
    module Header
      class Component < ApplicationViewComponent
        renders_one :title, "Shadcn::Card::Title::Component"
        renders_one :description, "Shadcn::Card::Description::Component"
        renders_one :action, "Shadcn::Card::Action::Component"

        slot_name :"card-header"

        style do
          base {
            "@container/card-header grid auto-rows-min grid-rows-[auto_auto] items-start " \
            "gap-2 px-6 has-data-[slot=card-action]:grid-cols-[1fr_auto] [.border-b]:pb-6"
          }
        end

        def call
          render_element(body: safe_join([ title, description, action, content ].compact))
        end
      end
    end
  end
end
