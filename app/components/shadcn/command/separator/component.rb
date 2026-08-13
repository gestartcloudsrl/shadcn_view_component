# frozen_string_literal: true

module Shadcn
  module Command
    module Separator
      # A rule between groups, and decorative: `aria-hidden` where cmdk writes
      # `role="separator"` (`vendor/cmdk/index.tsx:780`).
      #
      # A `role="listbox"` may only contain options and groups, and upstream's
      # own palette puts the separator inside the list — so cmdk's markup makes
      # the listbox invalid, and axe fails it. Nothing is lost by hiding it: a
      # separator with no name conveys nothing to a screen reader, and the
      # groups either side of it are already named. This is the same call the
      # toaster made about a `role` on an `<li>`.
      class Component < ApplicationViewComponent
        default_tag :div
        slot_name :"command-separator"

        style do
          base { "-mx-1 h-px bg-border" }
        end

        def element_attributes(**defaults)
          super(**{
            "cmdk-separator" => "",
            "aria-hidden" => "true",
            "data-shadcn--command-target" => "separator"
          }.merge(defaults))
        end
      end
    end
  end
end
