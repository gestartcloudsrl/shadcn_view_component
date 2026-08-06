# frozen_string_literal: true

module Shadcn
  module Sheet
    module Header
      # SheetHeader
      class Component < ApplicationViewComponent
        renders_one :title, "Shadcn::Sheet::Title::Component"
        renders_one :description, "Shadcn::Sheet::Description::Component"

        slot_name :"sheet-header"

        style do
          base { "flex flex-col gap-1.5 p-4" }
        end

        def call
          render_element(body: safe_join([ title, description, content ].compact))
        end
      end
    end
  end
end
