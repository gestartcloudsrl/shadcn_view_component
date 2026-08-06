# frozen_string_literal: true

module ShadcnViewComponent
  # `shadcn_form_with` is `form_with` with the shadcn builder already set, so
  # the `f.shadcn_*` helpers are available without repeating `builder:`.
  #
  #   <%= shadcn_form_with model: @user do |f| %>
  #     <%= f.shadcn_input_field :email, label: "Email", type: "email" %>
  #     <%= f.shadcn_submit "Save" %>
  #   <% end %>
  #
  # `form_with(..., builder: ShadcnViewComponent::FormBuilder)` does the same
  # thing if you would rather be explicit.
  module FormHelper
    def shadcn_form_with(**options, &block)
      form_with(**options.reverse_merge(builder: ShadcnViewComponent::FormBuilder), &block)
    end

    # For `fields_for` / `form_for` call sites that want the builder without the
    # helper above.
    def shadcn_form_builder
      ShadcnViewComponent::FormBuilder
    end
  end
end
