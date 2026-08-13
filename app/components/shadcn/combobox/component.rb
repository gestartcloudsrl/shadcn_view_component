# frozen_string_literal: true

module Shadcn
  module Combobox
    # Port of registry/new-york-v4/ui/combobox.tsx — the one file of the 61 that
    # is written against **Base UI** rather than Radix.
    #
    # That is the whole story of this port, and it is visible in the class
    # strings: `data-open:`, `data-closed:`, `--anchor-width`,
    # `--available-height`. Every other family here emits `data-state="open"`
    # and reads `--radix-*`. Reproducing upstream's classes therefore means
    # emitting Base UI's conventions in this family and nowhere else — which is
    # what this does, and what `popper.js` publishes the four unprefixed
    # variables for. See
    # [features/combobox.md](../../../../.claude/docs/features/combobox.md).
    #
    # The root itself renders nothing upstream (`const Combobox =
    # ComboboxPrimitive.Root`, a context provider), so it is a `display:
    # contents` wrapper here — the same shape every context-only root in this
    # gem takes.
    class Component < ApplicationViewComponent
      default_tag :div
      slot_name :combobox

      renders_one :combobox_input, "Shadcn::Combobox::Input::Component"
      renders_one :combobox_content, "Shadcn::Combobox::Content::Component"

      attr_reader :name, :value, :label

      # `name:` submits with the form, as every other control in this gem does
      # through a hidden input; `value:` is what is chosen and `label:` what is
      # shown for it.
      def initialize(name: nil, value: nil, label: nil, **attributes)
        @name = name
        @value = value
        @label = label
        super(**attributes)
      end

      def element_attributes(**defaults)
        super(**{
          style: merged_style("display:contents"),
          "data-controller" => "shadcn--combobox",
          "data-shadcn--combobox-value-value" => value
        }.compact.merge(defaults))
      end

      def call
        render_element(body: safe_join([ combobox_input, combobox_content, hidden_input ].compact))
      end

      private

      def hidden_input
        return if name.blank?

        tag.input(type: "hidden", name:, value:, autocomplete: "off",
                  "data-shadcn--combobox-target": "input")
      end
    end
  end
end
