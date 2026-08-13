# frozen_string_literal: true

module Shadcn
  module Command
    # Port of registry/new-york-v4/ui/command.tsx, whose behaviour is `cmdk` —
    # 1,091 lines of TSX plus a 162-line fuzzy scorer, over four Radix packages,
    # vendored at `vendor/cmdk/`.
    #
    # Every class is in the TSX, and unlike `chart.tsx` its selectors reach a
    # DOM this port renders: `[cmdk-item]`, `[cmdk-group-heading]`,
    # `[cmdk-input-wrapper]` are how shadcn spaces the palette out, so the parts
    # carry those bare attributes and upstream's own rules apply. See
    # [features/command.md](../../../../.claude/docs/features/command.md).
    class Component < ApplicationViewComponent
      default_tag :div
      slot_name :command

      style do
        base { "flex h-full w-full flex-col overflow-hidden rounded-md bg-popover text-popover-foreground" }
      end

      renders_one :command_input, ->(**options) { Input::Component.new(ids:, **options) }
      renders_one :command_list, ->(**options) { List::Component.new(ids:, **options) }

      attr_reader :label

      # `label:` names the listbox, as cmdk's own `label` prop does
      # (`vendor/cmdk/index.tsx:350`): a list of options is a control, and a
      # control with no name is one a screen reader reads as nothing.
      def initialize(label: nil, **attributes)
        @label = label
        super(**attributes)
      end

      # The three ids the ARIA wiring needs, decided once here and handed to the
      # parts: an input points `aria-controls` at the list, and the list is
      # named by a label that may not exist yet when the input renders.
      def ids
        @ids ||= { input: generated(:input), list: generated(:list), label: generated(:label) }
      end

      def element_attributes(**defaults)
        super(**{
          "cmdk-root" => "",
          "data-controller" => "shadcn--command"
        }.merge(defaults))
      end

      def call
        render_element(body: safe_join([ hidden_label, command_input, command_list, content ].compact))
      end

      private

      # cmdk renders the label as a visually hidden element when it is given a
      # string (index.tsx:591-596). Without it `aria-labelledby` on the input
      # points at nothing, which is worse than no label at all.
      def hidden_label
        return unless label.present?

        tag.label(label, id: ids[:label], for: ids[:input], class: "sr-only")
      end

      def generated(part) = "shadcn-command-#{part}-#{SecureRandom.hex(4)}"
    end
  end
end
