# frozen_string_literal: true

module ShadcnViewComponent
  # Bridges the components to Rails forms.
  #
  # shadcn's `Field` family is the right shape for this — label, control,
  # description, error — but on its own it knows nothing about a model. This
  # builder wires the two together: ids and names come from Rails, the error
  # text and `aria-invalid` come from `ActiveModel::Errors`, and `Field` gets the
  # `data-invalid` its styles key off.
  #
  #   <%= shadcn_form_with model: @user do |f| %>
  #     <%= f.shadcn_field :email, label: "Email", description: "We never share it." do %>
  #       <%= f.shadcn_input :email, type: "email" %>
  #     <% end %>
  #   <% end %>
  #
  # Or, when the control needs no arguments of its own:
  #
  #   <%= f.shadcn_input_field :email, label: "Email", type: "email" %>
  class FormBuilder < ActionView::Helpers::FormBuilder
    # A labelled control with its description and any validation errors, wired
    # together by id. `Field` styles itself from `data-invalid`, so that is set
    # from the model rather than passed in.
    #
    # @param method [Symbol] the attribute
    # @param label [String] omit to leave the label out entirely
    # @param description [String] hint text below the control
    # @param orientation [Symbol] :vertical, :horizontal or :responsive
    def shadcn_field(method, label: nil, description: nil, orientation: :vertical, **options, &block)
      messages = errors_for(method)
      described[method.to_s] = description.present?

      @template.render(Shadcn::Field::Component.new(
        orientation:,
        "data-invalid": (true if messages.any?),
        **options
      )) do |field|
        field.with_label(id: label_id(method), for: field_id(method)) { label } if label
        field.with_field_content { @template.capture(&block) }
        field.with_description(id: description_id(method)) { description } if description
        field.with_error(id: error_id(method), errors: messages) if messages.any?
      end
    end

    # `shadcn_input_field`, `shadcn_textarea_field`, … — the common case where
    # the field wraps exactly one control.
    %i[input textarea native_select switch checkbox].each do |control|
      define_method(:"shadcn_#{control}_field") do |method, label: nil, description: nil, orientation: nil, **options|
        shadcn_field(
          method,
          label:,
          description:,
          orientation: orientation || (%i[switch checkbox].include?(control) ? :horizontal : :vertical)
        ) { public_send(:"shadcn_#{control}", method, **options) }
      end
    end

    def shadcn_input(method, **options)
      @template.render(Shadcn::Input::Component.new(**control_options(method, **options)))
    end

    def shadcn_textarea(method, **options)
      @template.render(Shadcn::Textarea::Component.new(**control_options(method, **options))) do
        value_for(method).to_s
      end
    end

    # A real `<select>`: browser validation, autofill and keyboard behaviour for
    # free. Prefer it over `shadcn_select` unless you need the styled listbox.
    def shadcn_native_select(method, choices = [], **options)
      @template.render(Shadcn::NativeSelect::Component.new(**control_options(method, **options))) do
        @template.safe_join(Array(choices).map { |choice| native_option(method, choice) })
      end
    end

    # The Radix-style listbox. It submits through a hidden input, so it has no
    # browser validation — `required` will not stop the form.
    def shadcn_select(method, choices = [], placeholder: nil, **options)
      selected = value_for(method).to_s

      @template.render(Shadcn::Select::Component.new(
        name: field_name(method), value: selected, placeholder:, **options
      )) do |select|
        select.with_trigger(**aria_labelled(method,
                                            id: field_id(method),
                                            placeholder: selected.blank?,
                                            "aria-invalid": invalid(method))) do |trigger|
          trigger.with_value(placeholder:) { label_for(choices, selected) }
        end
        select.with_select_content do
          @template.safe_join(Array(choices).map { |choice|
            label, value = option_pair(choice)
            @template.render(Shadcn::Select::Item::Component.new(value:, selected: value == selected)) { label }
          })
        end
      end
    end

    def shadcn_checkbox(method, **options)
      @template.render(Shadcn::Checkbox::Component.new(
        name: field_name(method),
        checked: !!value_for(method),
        **aria_labelled(method, **control_options(method, **options))
      ))
    end

    def shadcn_switch(method, **options)
      @template.render(Shadcn::Switch::Component.new(
        name: field_name(method),
        checked: !!value_for(method),
        **aria_labelled(method, **control_options(method, **options))
      ))
    end

    # Each option is rendered as block content rather than through the `item`
    # slot: the items have to sit inside their own label rows, and slot content
    # is emitted before block content, which would pull them all out of place.
    def shadcn_radio_group(method, choices = [], **options)
      selected = value_for(method).to_s

      @template.render(Shadcn::RadioGroup::Component.new(
        name: field_name(method), value: selected, **options
      )) do
        @template.safe_join(Array(choices).map { |choice|
          label, value = option_pair(choice)
          id = "#{field_id(method)}_#{value.parameterize.underscore}"

          @template.tag.div(class: "flex items-center gap-2") do
            @template.safe_join([
              @template.render(Shadcn::RadioGroup::Item::Component.new(
                value:, checked: value == selected, id:
              )),
              @template.render(Shadcn::Label::Component.new(for: id)) { label }
            ])
          end
        })
      end
    end

    def shadcn_submit(text = nil, **options, &block)
      @template.render(Shadcn::Button::Component.new(type: "submit", **options)) do
        block ? @template.capture(&block) : (text || submit_default_value)
      end
    end

    private

    # Which attributes have actually had a description rendered. `aria-describedby`
    # may only name elements that exist — a reference to a missing id is invalid
    # ARIA and simply resolves to nothing, so the control ends up describing
    # itself as having a description it does not have.
    #
    # Upstream has the same defect and it is not reproduced on purpose:
    # `FormControl` sets `aria-describedby` to the description id unconditionally
    # (form.tsx:113-119), whether or not a `FormDescription` was ever rendered.
    # This port shipped it too, until writing features/form.md checked the claim
    # that it did not.
    #
    # A control rendered outside any `shadcn_field` is the same case and gets the
    # same answer: no description element, so nothing to point at.
    def described
      @described ||= {}
    end

    def errors_for(method)
      return [] unless object.respond_to?(:errors)

      object.errors[method] || []
    end

    def invalid(method)
      "true" if errors_for(method).any?
    end

    def value_for(method)
      object.respond_to?(method) ? object.public_send(method) : nil
    end

    # Everything a control needs to belong to the form and to announce itself.
    def control_options(method, **options)
      wants_description = options.delete(:described_by) != false
      described_by = [
        (description_id(method) if wants_description && described[method.to_s]),
        (error_id(method) if errors_for(method).any?)
      ].compact

      {
        id: field_id(method),
        name: field_name(method),
        value: value_for(method),
        "aria-invalid": invalid(method),
        "aria-describedby": described_by.presence&.join(" ")
      }.compact.merge(options)
    end

    def description_id(method) = "#{field_id(method)}_description"
    def error_id(method) = "#{field_id(method)}_error"
    def label_id(method) = "#{field_id(method)}_label"

    # Select, Checkbox and Switch render a `<button>` carrying an ARIA role, and
    # a `<label for>` does not name a button — `role="combobox"` goes further and
    # forbids taking the name from its own content. So they are named by pointing
    # at the label instead. Without this they reach the browser unnamed, which
    # `spec/system/accessibility_spec.rb` catches.
    def aria_labelled(method, options)
      return options if options.key?(:"aria-label") || options.key?(:"aria-labelledby")

      options.merge("aria-labelledby": label_id(method))
    end

    # Accepts the same shapes as Rails' `options_for_select`: bare values, or
    # `[label, value]` pairs.
    def option_pair(choice)
      choice.is_a?(Array) ? [ choice.first.to_s, choice.last.to_s ] : [ choice.to_s, choice.to_s ]
    end

    def label_for(choices, value)
      Array(choices).map { |choice| option_pair(choice) }.find { |(_label, v)| v == value }&.first
    end

    def native_option(method, choice)
      label, value = option_pair(choice)

      @template.render(Shadcn::NativeSelect::Option::Component.new(
        value:, selected: value == value_for(method).to_s
      )) { label }
    end
  end
end
