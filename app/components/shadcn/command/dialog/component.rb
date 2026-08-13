# frozen_string_literal: true

module Shadcn
  module Command
    module Dialog
      # The palette: a Command inside a Dialog, which is what upstream's
      # `CommandDialog` is — it renders no markup of its own beyond the classes
      # it layers on both.
      #
      # The title and the description are `sr-only` and required rather than
      # optional, exactly as upstream defaults them: a dialog with no
      # accessible name is a dialog a screen reader opens into silence.
      class Component < ApplicationViewComponent
        # Upstream's own spacing for a palette in a dialog, which is where the
        # `cmdk-*` attributes earn their keep: the rows are taller and the
        # headings are indented, and every selector reaches this port's DOM.
        COMMAND_CLASSES = "**:data-[slot=command-input-wrapper]:h-12 [&_[cmdk-group-heading]]:px-2 " \
                          "[&_[cmdk-group-heading]]:font-medium [&_[cmdk-group-heading]]:text-muted-foreground " \
                          "[&_[cmdk-group]]:px-2 [&_[cmdk-group]:not([hidden])_~[cmdk-group]]:pt-0 " \
                          "[&_[cmdk-input-wrapper]_svg]:h-5 [&_[cmdk-input-wrapper]_svg]:w-5 " \
                          "[&_[cmdk-input]]:h-12 [&_[cmdk-item]]:px-2 [&_[cmdk-item]]:py-3 " \
                          "[&_[cmdk-item]_svg]:h-5 [&_[cmdk-item]_svg]:w-5"
        CONTENT_CLASSES = "overflow-hidden p-0"

        attr_reader :title, :description, :show_close_button, :label

        def initialize(title: "Command Palette", description: "Search for a command to run...",
                       show_close_button: true, label: nil, **attributes)
          @title = title
          @description = description
          @show_close_button = show_close_button
          @label = label
          super(**attributes)
        end

        # The trigger belongs to the Dialog, not to this component, so the slot
        # only *carries* what the caller wrote — its content, and the attributes
        # that come with it — and `call` hands both to the Dialog's own trigger.
        # Nesting one trigger inside another renders an empty button, which is
        # what axe reported the first time.
        # `view_context.capture`, and the block kept rather than rendered here:
        # the block was written in the caller's template, so capturing it inside
        # this component writes to the wrong buffer and the button comes out
        # empty — which is what axe reported, twice.
        renders_one :trigger, lambda { |**options, &block|
          @trigger_options = options
          @trigger_block = block
          nil
        }

        def call
          render(Shadcn::Dialog::Component.new(**attributes)) do |dialog|
            dialog.with_trigger(**@trigger_options.to_h) { view_context.capture(&@trigger_block) } if trigger?
            dialog.with_dialog_content(class: CONTENT_CLASSES, show_close_button:) do |dialog_content|
              dialog_content.with_header(class: "sr-only") do |header|
                header.with_title { title }
                header.with_description { description }
              end
              concat(command)
            end
          end
        end

        private

        def command
          render(Command::Component.new(label:, class: COMMAND_CLASSES)) { content }
        end
      end
    end
  end
end
