# frozen_string_literal: true

module Shadcn
  module Select
    module Trigger
      # SelectTrigger
      class Component < ApplicationViewComponent
        CHEVRON_CLASSES = "size-4 opacity-50"

        renders_one :value, "Shadcn::Select::Value::Component"

        default_tag :button
        slot_name :"select-trigger"

        style do
          base {
            "flex w-fit items-center justify-between gap-2 rounded-md border border-input " \
            "bg-transparent px-3 py-2 text-sm whitespace-nowrap shadow-xs " \
            "transition-[color,box-shadow] outline-none focus-visible:border-ring " \
            "focus-visible:ring-[3px] focus-visible:ring-ring/50 " \
            "disabled:cursor-not-allowed disabled:opacity-50 " \
            "aria-invalid:border-destructive aria-invalid:ring-destructive/20 " \
            "data-[placeholder]:text-muted-foreground data-[size=default]:h-9 " \
            "data-[size=sm]:h-8 *:data-[slot=select-value]:line-clamp-1 " \
            "*:data-[slot=select-value]:flex *:data-[slot=select-value]:items-center " \
            "*:data-[slot=select-value]:gap-2 dark:bg-input/30 dark:hover:bg-input/50 " \
            "dark:aria-invalid:ring-destructive/40 [&_svg]:pointer-events-none " \
            "[&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 " \
            "[&_svg:not([class*='text-'])]:text-muted-foreground"
          }
        end

        attr_reader :size, :placeholder, :disabled, :searchable

        def initialize(size: :default, placeholder: true, disabled: false,
                       searchable: false, **attributes)
          @size = size&.to_sym || :default
          @placeholder = placeholder
          @disabled = disabled
          @searchable = searchable
          super(**attributes)
        end

        def element_attributes(**defaults)
          super(**{
            type: "button",
            # A searchable select's trigger is a plain button announcing a
            # listbox popup: the typing happens in the field inside the popover,
            # not here. shadcn's aria variant emits it that way, and it has the
            # side benefit that a role-less button can take its accessible name
            # from its own text, which `role="combobox"` cannot.
            role: ("combobox" unless searchable),
            disabled: (true if disabled),
            "aria-expanded" => "false",
            "aria-haspopup" => ("listbox" if searchable),
            "aria-autocomplete" => ("none" unless searchable),
            "data-size" => size,
            "data-state" => "closed",
            "data-placeholder" => (true if placeholder),
            "data-shadcn--select-target" => "trigger",
            "data-action" => "click->shadcn--select#toggle " \
                             "keydown->shadcn--select#triggerKeydown"
          }.merge(defaults))
        end

        def call
          render_element(body: safe_join([ value, content, chevron ].compact))
        end

        private

        def chevron
          render(Icon::Component.new("chevron-down", class: CHEVRON_CLASSES))
        end
      end
    end
  end
end
