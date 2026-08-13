# frozen_string_literal: true

module Shadcn
  module Command
    module List
      # The scrolling list of options. `role="listbox"`, and the input drives it
      # from outside through `aria-activedescendant` — the virtual focus this
      # gem already uses for the searchable select.
      class Component < ApplicationViewComponent
        default_tag :div
        slot_name :"command-list"

        style do
          base { "max-h-[300px] scroll-py-1 overflow-x-hidden overflow-y-auto" }
        end

        attr_reader :ids

        def initialize(ids: {}, **attributes)
          @ids = ids
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{
            "cmdk-list" => "",
            id: ids[:list],
            role: "listbox",
            "aria-labelledby" => ids[:label],
            "data-shadcn--command-target" => "list"
          }.compact.merge(defaults))
        end
      end
    end
  end
end
