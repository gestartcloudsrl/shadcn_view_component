# frozen_string_literal: true

module Shadcn
  module Command
    module Empty
      # What is shown when nothing matches. Rendered hidden and revealed by the
      # controller: the server cannot know what a caller will type, and an empty
      # state that only exists once JavaScript has run is one a reader sees
      # flash in.
      class Component < ApplicationViewComponent
        default_tag :div
        slot_name :"command-empty"

        style do
          base { "py-6 text-center text-sm" }
        end

        def element_attributes(**defaults)
          super(**{
            "cmdk-empty" => "",
            role: "presentation",
            hidden: true,
            "data-shadcn--command-target" => "empty"
          }.merge(defaults))
        end
      end
    end
  end
end
