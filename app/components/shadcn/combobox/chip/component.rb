# frozen_string_literal: true

module Shadcn
  module Combobox
    module Chip
      # One chosen value, with the X that takes it back off. `show_remove:` is
      # upstream's `showRemove`, on by default there too.
      class Component < ApplicationViewComponent
        REMOVE_CLASSES = "-ml-1 opacity-50 hover:opacity-100"

        default_tag :span
        slot_name :"combobox-chip"

        style do
          base {
            "flex h-[calc(--spacing(5.5))] w-fit items-center justify-center gap-1 rounded-sm bg-muted " \
            "px-1.5 text-xs font-medium whitespace-nowrap text-foreground has-disabled:pointer-events-none " \
            "has-disabled:cursor-not-allowed has-disabled:opacity-50 " \
            "has-data-[slot=combobox-chip-remove]:pr-0"
          }
        end

        attr_reader :value, :show_remove

        def initialize(value: nil, show_remove: true, **attributes)
          @value = value
          @show_remove = show_remove
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{
            "data-value" => value,
            "data-shadcn--combobox-target" => "chip"
          }.compact.merge(defaults))
        end

        def call
          render_element(body: safe_join([ content, remove ].compact))
        end

        private

        def remove
          return unless show_remove

          render(Shadcn::Button::Component.new(
            variant: :ghost,
            size: :"icon-xs",
            class: REMOVE_CLASSES,
            "data-slot": "combobox-chip-remove",
            "data-value": value,
            "data-action": "click->shadcn--combobox#remove",
            "aria-label": shadcn_t("combobox.remove")
          )) { render(Icon::Component.new("x", class: "pointer-events-none")) }
        end
      end
    end
  end
end
