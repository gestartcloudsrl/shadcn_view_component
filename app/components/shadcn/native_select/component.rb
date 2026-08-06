# frozen_string_literal: true

module Shadcn
  module NativeSelect
    # Port of registry/new-york-v4/ui/native-select.tsx — a real <select> with
    # the native chevron replaced by a lucide icon.
    class Component < ApplicationViewComponent
      WRAPPER_CLASSES = "group/native-select relative w-fit has-[select:disabled]:opacity-50"

      ICON_CLASSES = "pointer-events-none absolute top-1/2 right-3.5 size-4 " \
                     "-translate-y-1/2 text-muted-foreground opacity-50 select-none"

      default_tag :select
      slot_name :"native-select"

      style do
        base {
          "h-9 w-full min-w-0 appearance-none rounded-md border border-input bg-transparent " \
          "px-3 py-2 pr-9 text-sm shadow-xs transition-[color,box-shadow] outline-none " \
          "selection:bg-primary selection:text-primary-foreground " \
          "placeholder:text-muted-foreground disabled:pointer-events-none " \
          "disabled:cursor-not-allowed data-[size=sm]:h-8 data-[size=sm]:py-1 " \
          "dark:bg-input/30 dark:hover:bg-input/50 " \
          "focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 " \
          "aria-invalid:border-destructive aria-invalid:ring-destructive/20 " \
          "dark:aria-invalid:ring-destructive/40"
        }
      end

      attr_reader :size

      def initialize(size: :default, **attributes)
        @size = size&.to_sym || :default
        super(**attributes)
      end

      def element_attributes(**defaults)
        super(**{ "data-size" => size }.merge(defaults))
      end

      def call
        tag.div(class: WRAPPER_CLASSES, "data-slot": "native-select-wrapper") do
          safe_join([ render_element(body: content), chevron ])
        end
      end

      private

      def chevron
        render(Icon::Component.new(
          "chevron-down",
          class: ICON_CLASSES,
          "aria-hidden": "true",
          "data-slot": "native-select-icon"
        ))
      end
    end
  end
end
