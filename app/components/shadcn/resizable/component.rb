# frozen_string_literal: true

module Shadcn
  module Resizable
    # Port of registry/new-york-v4/ui/resizable.tsx, whose behaviour is
    # `react-resizable-panels` — 2,252 lines of compiled JavaScript and no
    # dependencies of its own.
    #
    # What the package supplies is a drag, a keyboard and some arithmetic over
    # `flex-grow`: panels are proportions of a flex container, so the layout is
    # the browser's and the port only has to move two numbers when a handle is
    # dragged. See [features/resizable.md](../../../../.claude/docs/features/resizable.md).
    #
    # Panels and handles are written in the block, in order, because that is
    # what a group is — `panel, handle, panel` — and because slot content is
    # emitted before block content, which would gather all the panels above all
    # the handles.
    class Component < ApplicationViewComponent
      ORIENTATIONS = %i[horizontal vertical].freeze

      default_tag :div
      slot_name :"resizable-panel-group"

      style do
        base { "flex h-full w-full aria-[orientation=vertical]:flex-col" }
      end

      attr_reader :orientation

      # `orientation:` is upstream's `direction`, renamed to what the DOM calls
      # it: the class above reads `aria-orientation`, and a group that says
      # `direction` in Ruby and `orientation` in HTML is one name too many.
      def initialize(orientation: :horizontal, **attributes)
        @orientation = ORIENTATIONS.include?(orientation&.to_sym) ? orientation.to_sym : :horizontal
        super(**attributes)
      end

      # No `aria-orientation`, and the direction is an inline style — which is
      # what upstream's own DOM does, and was arrived at the hard way.
      #
      # The class above reads `aria-[orientation=vertical]:flex-col`, so the
      # obvious port writes that attribute; axe then refuses it, because no role
      # a plain group can carry supports `aria-orientation`. Reading what
      # `react-resizable-panels` v4 actually renders settles it: the group has
      # no role and no `aria-orientation` at all, and sets `flex-direction`
      # inline. **The class is vestigial upstream too** — it reads an attribute
      # the package stopped rendering. It is kept because `parity_spec` compares
      # what upstream emits, and dropping it would claim a divergence that is
      # not one.
      def element_attributes(**defaults)
        super(**{
          "data-controller" => "shadcn--resizable",
          "data-shadcn--resizable-orientation-value" => orientation,
          style: merged_style(("flex-direction:column" if orientation == :vertical))
        }.compact.merge(defaults))
      end
    end
  end
end
