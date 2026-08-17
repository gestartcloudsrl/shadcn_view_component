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

      # In multiple mode the chips box replaces the field — upstream renders
      # `ComboboxChips` where the single-selection examples render
      # `ComboboxInput`, and the field moves *inside* it as `ComboboxChipsInput`.
      # A separate slot rather than a variant of `combobox_input`, because the
      # two are different components with different parents.
      renders_one :combobox_chips, "Shadcn::Combobox::Chips::Component"

      attr_reader :name, :label, :multiple

      # `name:` submits with the form, as every other control in this gem does
      # through a hidden input; `value:` is what is chosen and `label:` what is
      # shown for it.
      #
      # `multiple:` is Base UI's own prop — "Whether multiple items can be
      # selected" — and, as there, `value:` then takes an array. It submits the
      # way Rails expects a collection to: `name` gains `[]` and there is one
      # hidden input per chosen value, so `params[:post][:tag_ids]` is an array
      # with no parsing on the receiving end.
      def initialize(name: nil, value: nil, label: nil, multiple: false, **attributes)
        @name = name
        @multiple = multiple
        @values = Array.wrap(value).map(&:to_s).reject(&:blank?)
        @label = label
        super(**attributes)
      end

      # The single chosen value. In multiple mode there is no such thing, and
      # the controller reads `values` instead.
      def value
        multiple ? nil : @values.first
      end

      def values
        @values
      end

      def element_attributes(**defaults)
        super(**{
          style: merged_style("display:contents"),
          "data-controller" => "shadcn--combobox",
          "data-shadcn--combobox-value-value" => value,
          "data-shadcn--combobox-multiple-value" => (multiple.presence && "true"),
          "data-shadcn--combobox-values-value" => (values.to_json if multiple),
          # The controller writes the hidden inputs as chips come and go, and
          # needs a name to write them under. Kept off the DOM when there is no
          # name, like the inputs themselves.
          "data-shadcn--combobox-name-value" => (field_name if multiple && name.present?)
        }.compact.merge(defaults))
      end

      def call
        render_element(body: safe_join([ combobox_input, combobox_chips, combobox_content, *hidden_inputs ].compact))
      end

      private

      # Rails reads `foo[]` as a collection and `foo` as a scalar, so the
      # brackets are what make several hidden inputs arrive as an array rather
      # than as the last one to be parsed. Added only when the caller has not
      # written them already.
      def field_name
        return name if !multiple || name.to_s.end_with?("[]")

        "#{name}[]"
      end

      def hidden_inputs
        return [] if name.blank?
        return [ hidden_input(value) ] unless multiple

        # An empty one first, so clearing every chip still submits the
        # parameter — otherwise the key vanishes from the params and Rails
        # leaves the association untouched instead of emptying it. This is the
        # same trick `collection_select ... include_hidden: true` plays.
        [ hidden_input("", target: false), *values.map { |v| hidden_input(v) } ]
      end

      def hidden_input(field_value, target: true)
        attrs = { type: "hidden", name: field_name, value: field_value, autocomplete: "off" }
        attrs["data-shadcn--combobox-target"] = "input" if target

        tag.input(**attrs)
      end
    end
  end
end
