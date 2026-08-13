# frozen_string_literal: true

module Shadcn
  module Command
    module Input
      # The search field, wrapped in the row that holds the magnifier —
      # upstream renders both from one component and gives each its own slot.
      class Component < ApplicationViewComponent
        WRAPPER_CLASSES = "flex h-9 items-center gap-2 border-b px-3"
        ICON_CLASSES = "size-4 shrink-0 opacity-50"

        default_tag :input
        slot_name :"command-input"

        style do
          base {
            "flex h-10 w-full rounded-md bg-transparent py-3 text-sm outline-hidden " \
            "placeholder:text-muted-foreground disabled:cursor-not-allowed disabled:opacity-50"
          }
        end

        attr_reader :ids

        def initialize(ids: {}, **attributes)
          @ids = ids
          super(**attributes)
        end

        # cmdk's own attributes, read from `vendor/cmdk/index.tsx:801-816`. The
        # combobox is always expanded because the list is always there — a
        # palette has nothing to open.
        def element_attributes(**defaults)
          super(**{
            "cmdk-input" => "",
            type: "text",
            id: ids[:input],
            role: "combobox",
            autocomplete: "off",
            autocorrect: "off",
            spellcheck: "false",
            "aria-autocomplete" => "list",
            "aria-expanded" => "true",
            "aria-controls" => ids[:list],
            "aria-labelledby" => ids[:label],
            "data-shadcn--command-target" => "search",
            "data-action" => "input->shadcn--command#search keydown->shadcn--command#keydown"
          }.compact.merge(defaults))
        end

        # The wrapper is the component's own markup rather than a part a caller
        # composes, which is upstream's shape too.
        def call
          tag.div(
            safe_join([
              render(Icon::Component.new("search", class: ICON_CLASSES)),
              render_element
            ]),
            class: WRAPPER_CLASSES,
            "data-slot": "command-input-wrapper",
            "cmdk-input-wrapper": ""
          )
        end
      end
    end
  end
end
