# frozen_string_literal: true

module Shadcn
  module Concerns
    # Shared behaviour of the three components shadcn builds on Radix's Dialog
    # primitive: Dialog, Sheet and AlertDialog.
    #
    # It is a module rather than a superclass because ViewComponent refuses to
    # let a subclass redeclare an inherited slot, and each of the three needs
    # its own `trigger` / content slot types.
    module ModalRoot
      def self.included(base)
        base.class_eval do
          attr_reader :open, :modal
        end
      end

      # Radix keeps alert dialogs open on an outside click; AlertDialog says so
      # by overriding this.
      def dismissable? = true

      def initialize(open: false, modal: true, **attributes)
        @open = open
        @modal = modal
        super(**attributes)
      end

      def element_attributes(**defaults)
        super(**{
          style: merged_style(ApplicationViewComponent::CONTENTS_STYLE),
          "data-controller" => "shadcn--dialog",
          "data-shadcn--dialog-open-value" => open,
          "data-shadcn--dialog-modal-value" => modal,
          "data-shadcn--dialog-dismissable-value" => dismissable?
        }.merge(defaults))
      end

      def call
        render_element(body: safe_join([ trigger, dialog_content, content ].compact))
      end
    end
  end
end
