# frozen_string_literal: true

module Shadcn
  module Select
    module List
      # Where the options live once a search field shares the popover.
      #
      # In the plain select the listbox role sits on SelectContent itself. It
      # cannot when a text field is in there too: a textbox is not an allowed
      # child of a listbox, and axe reports `aria-required-children` — critical —
      # for exactly that shape. shadcn's aria variant splits them the same way.
      #
      # Classes are that variant's verbatim, except `p-1` for its `p-0`: the
      # padding this port keeps on the viewport moves here, because the viewport
      # now holds the search field too.
      class Component < ApplicationViewComponent
        slot_name :"select-list"

        style do
          base {
            "group/select-list max-h-[inherit] overflow-x-hidden overflow-y-auto p-1 outline-hidden"
          }
        end

        def element_attributes(**defaults)
          # A named listbox, because an unnamed one is an
          # `aria-input-field-name` violation — serious, and WCAG rather than
          # best-practice. The dialog around it is named separately, so a
          # screen reader announces the popover and then the list rather than
          # the same words twice. shadcn's aria variant names both too.
          super(**{
            role: "listbox",
            "data-action" => "scroll->shadcn--select#syncScrollButtons",
            "aria-label" => shadcn_t("select.list_label"),
            "data-shadcn--select-target" => "list"
          }.merge(defaults))
        end
      end
    end
  end
end
