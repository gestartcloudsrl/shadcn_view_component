# frozen_string_literal: true

module Shadcn
  module Sheet
    # Port of registry/new-york-v4/ui/sheet.tsx — shadcn builds the Sheet on the
    # very same Radix Dialog primitive, so the port shares its behaviour.
    class Component < ApplicationViewComponent
      include Concerns::ModalRoot

      renders_one :trigger, "Shadcn::Sheet::Trigger::Component"
      renders_one :dialog_content, "Shadcn::Sheet::Content::Component"

      slot_name :sheet
    end
  end
end
