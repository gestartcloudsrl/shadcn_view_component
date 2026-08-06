# frozen_string_literal: true

module Shadcn
  module Kbd
    module Group
      # KbdGroup — note shadcn types it as a div but renders a <kbd>.
      class Component < ApplicationViewComponent
        default_tag :kbd
        slot_name :"kbd-group"

        style do
          base { "inline-flex items-center gap-1" }
        end
      end
    end
  end
end
