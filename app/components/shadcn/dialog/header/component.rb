# frozen_string_literal: true

module Shadcn
  module Dialog
    module Header
      # DialogHeader
      class Component < ApplicationViewComponent
        renders_one :title, "Shadcn::Dialog::Title::Component"
        renders_one :description, "Shadcn::Dialog::Description::Component"

        slot_name :"dialog-header"

        style do
          base { "flex flex-col gap-2 text-center sm:text-left" }
        end

        def call
          render_element(body: safe_join([ title, description, content ].compact))
        end
      end
    end
  end
end
