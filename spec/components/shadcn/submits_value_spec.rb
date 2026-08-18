# frozen_string_literal: true

require "spec_helper"

# The hidden input is this library's invention — Radix bubbles a native control
# instead — so a host had no way to name it. These examples pin the opening.
RSpec.describe Shadcn::Concerns::SubmitsValue do
  # The three families whose value is a single scalar. Combobox, Slider and
  # Calendar render several inputs in their multi-valued modes and are
  # deliberately not included; see the concern for why.
  # A local rather than a constant: a constant declared in an example group
  # leaks into the global namespace for every spec that runs after it.
  families = {
    "Select" => ->(**kwargs) { Shadcn::Select::Component.new(name: "post[author_id]", **kwargs) },
    "RadioGroup" => ->(**kwargs) { Shadcn::RadioGroup::Component.new(name: "post[rating]", **kwargs) },
    "ToggleGroup" => ->(**kwargs) { Shadcn::ToggleGroup::Component.new(name: "post[align]", **kwargs) }
  }

  def hidden = fragment.at_css("input[type=hidden]")

  families.each do |family, build|
    describe family do
      it "reaches the input with what the caller asked for", :aggregate_failures do
        render_inline(build.call(input_attributes: { id: "the-id", form: "elsewhere" }))

        expect(hidden["id"]).to eq("the-id")
        expect(hidden["form"]).to eq("elsewhere")
      end

      # The point of the opening: a Stimulus controller on the element whose
      # value is the selection, which is what a dependent select needs.
      it "carries a caller's Stimulus controller" do
        render_inline(build.call(input_attributes: { data: { controller: "dependent" } }))

        expect(hidden["data-controller"]).to eq("dependent")
      end

      it "leaves the component's own target alone" do
        render_inline(build.call(input_attributes: { id: "the-id" }))

        expect(hidden.attributes.keys.grep(/-target\z/)).not_to be_empty
      end

      # Otherwise the input could be quietly detached from the control it
      # belongs to, and the form would submit something else — or nothing.
      it "keeps its own name and value against a caller's", :aggregate_failures do
        render_inline(build.call(input_attributes: { name: "hijacked", value: "hijacked" }))

        expect(hidden["name"]).not_to eq("hijacked")
        expect(hidden["value"]).not_to eq("hijacked")
      end

      it "adds nothing when the caller asks for nothing" do
        render_inline(build.call)

        expect(hidden.attributes.keys).to contain_exactly("type", "name", "value", a_string_matching(/-target\z/))
      end
    end
  end
end
