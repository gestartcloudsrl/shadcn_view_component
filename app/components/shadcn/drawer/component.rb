# frozen_string_literal: true

module Shadcn
  module Drawer
    # Port of registry/new-york-v4/ui/drawer.tsx
    #
    # vaul's Drawer.Root wraps Radix's Dialog.Root, so the open/close half of
    # this component *is* the dialog's and runs on `shadcn--dialog`: the focus
    # trap, the scroll lock, Escape, the outside click and the exit animation
    # are all already there and are not reimplemented. What vaul adds is the
    # drag, and that is `shadcn--drawer`, on the content — the same arrangement
    # the menubar has with the dropdown.
    class Component < ApplicationViewComponent
      include Concerns::ModalRoot

      renders_one :trigger, "Shadcn::Drawer::Trigger::Component"
      # `dialog_content` rather than `drawer_content`, which reads better here
      # but would make this the one modal family out of four with its own name
      # for the same slot — `ModalRoot` renders it, and Sheet and AlertDialog
      # both call it that.
      renders_one :dialog_content, "Shadcn::Drawer::Content::Component"

      slot_name :drawer

      # Two controllers on one element. `data-controller` is one of the
      # attributes that *replaces* rather than concatenates, so the dialog's own
      # string has to be repeated here rather than added to.
      def element_attributes(**defaults)
        super(**{ "data-controller" => "shadcn--dialog shadcn--drawer" }.merge(defaults))
      end
    end
  end
end
