# frozen_string_literal: true

require "spec_helper"

RSpec.describe ShadcnViewComponent::FormBuilder do
  # A plain ActiveModel, so the specs exercise the same path a real record does
  # without needing a database. Anonymous, because a constant declared in an
  # example group is defined on Object.
  let(:model_class) do
    Class.new do
      include ActiveModel::Model
      include ActiveModel::Attributes

      def self.name = "Signup"

      attribute :email, :string
      attribute :bio, :string
      attribute :plan, :string
      attribute :newsletter, :boolean

      validates :email, presence: true, format: { with: /@/, message: "must contain @" }
    end
  end

  let(:valid) { model_class.new(email: "a@b.com", plan: "pro", newsletter: true).tap(&:valid?) }
  let(:invalid) { model_class.new(plan: "pro").tap(&:valid?) }

  def render_form(model, template)
    html = ApplicationController.renderer.render(
      inline: "<%= shadcn_form_with(model: model, url: '/x', scope: :signup) do |f| %>#{template}<% end %>",
      locals: { model: }
    )
    Nokogiri::HTML5.fragment(html)
  end

  describe "#shadcn_field" do
    context "when the model has errors on the attribute" do
      subject(:doc) do
        render_form(
          invalid,
          "<%= f.shadcn_input_field :email, label: 'Email', description: 'Never shared.' %>"
        )
      end

      it "wires the label to the control", :aggregate_failures do
        expect(doc.at_css("[data-slot=field-label]")["for"]).to eq("signup_email")
        expect(doc.at_css("[data-slot=input]")["id"]).to eq("signup_email")
      end

      it "names the control for the form" do
        expect(doc.at_css("[data-slot=input]")["name"]).to eq("signup[email]")
      end

      it "marks the field and the control invalid", :aggregate_failures do
        expect(doc.at_css("[data-slot=field]")["data-invalid"]).to eq("true")
        expect(doc.at_css("[data-slot=input]")["aria-invalid"]).to eq("true")
      end

      it "renders every validation message" do
        messages = doc.at_css("[data-slot=field-error]").css("li").map(&:text)

        expect(messages).to eq([ "can't be blank", "must contain @" ])
      end

      it "points aria-describedby at both the description and the error", :aggregate_failures do
        expect(doc.at_css("[data-slot=input]")["aria-describedby"])
          .to eq("signup_email_description signup_email_error")
        expect(doc.at_css("[data-slot=field-description]")["id"]).to eq("signup_email_description")
        expect(doc.at_css("[data-slot=field-error]")["id"]).to eq("signup_email_error")
      end
    end

    context "when the model is valid" do
      subject(:doc) do
        render_form(valid, "<%= f.shadcn_input_field :email, label: 'Email' %>")
      end

      it "leaves the field and the control unmarked", :aggregate_failures do
        expect(doc.at_css("[data-slot=field]")["data-invalid"]).to be_nil
        expect(doc.at_css("[data-slot=input]")["aria-invalid"]).to be_nil
      end

      it "renders no error" do
        expect(doc.at_css("[data-slot=field-error]")).to be_nil
      end
    end

    context "without a label" do
      it "omits it" do
        doc = render_form(valid, "<%= f.shadcn_input_field :email %>")

        expect(doc.at_css("[data-slot=field-label]")).to be_nil
      end
    end
  end

  describe "#shadcn_input" do
    it "fills the input from the model" do
      doc = render_form(valid, "<%= f.shadcn_input :email %>")

      expect(doc.at_css("[data-slot=input]")["value"]).to eq("a@b.com")
    end
  end

  describe "#shadcn_textarea" do
    it "puts the value in the body, not an attribute" do
      model = model_class.new(bio: "hello").tap(&:valid?)
      doc = render_form(model, "<%= f.shadcn_textarea :bio %>")

      expect(doc.at_css("[data-slot=textarea]").text).to eq("hello")
    end
  end

  describe "#shadcn_native_select" do
    it "selects the current option" do
      doc = render_form(valid, "<%= f.shadcn_native_select :plan, [['Free', 'free'], ['Pro', 'pro']] %>")
      states = doc.css("[data-slot=native-select-option]").to_h { |o| [ o["value"], o["selected"] ] }

      expect(states).to eq("free" => nil, "pro" => "selected")
    end
  end

  describe "#shadcn_select" do
    subject(:doc) do
      render_form(valid, "<%= f.shadcn_select :plan, [['Free', 'free'], ['Pro', 'pro']] %>")
    end

    it "mirrors the value into a hidden input the form can post" do
      expect(doc.at_css("input[name='signup[plan]']")["value"]).to eq("pro")
    end

    it "shows the current choice on the trigger", :aggregate_failures do
      expect(doc.at_css("[data-slot=select-value]").text.strip).to eq("Pro")
      expect(doc.at_css("[data-value=pro]")["data-state"]).to eq("checked")
    end

    it "labels the trigger, which is a button no <label for> is aimed at" do
      expect(doc.at_css("[data-slot=select-trigger]")["aria-labelledby"]).to eq("signup_plan_label")
    end

    # `shadcn_select` forwards `**options` to the component, so `searchable:`
    # should already arrive without the builder knowing about it. That is a
    # claim about code, so it gets an example rather than a sentence.
    it "passes searchable through to the select" do
      doc = render_form(valid, "<%= f.shadcn_select :plan, [['Free', 'free']], searchable: true %>")

      expect(doc.at_css("[data-slot=select]")["data-shadcn--select-searchable-value"]).to eq("true")
      expect(doc.at_css("[data-slot=select-list]")).to be_present
    end
  end

  describe "#shadcn_switch" do
    it "checks from a boolean attribute", :aggregate_failures do
      doc = render_form(valid, "<%= f.shadcn_switch :newsletter %>")

      expect(doc.at_css("[data-slot=switch]")["data-state"]).to eq("checked")
      expect(doc.at_css("input[type=checkbox]")["name"]).to eq("signup[newsletter]")
    end
  end

  describe "#shadcn_checkbox" do
    it "checks from a boolean attribute", :aggregate_failures do
      doc = render_form(valid, "<%= f.shadcn_checkbox :newsletter %>")

      expect(doc.at_css("[data-slot=checkbox]")["data-state"]).to eq("checked")
      expect(doc.at_css("input[type=checkbox]")["name"]).to eq("signup[newsletter]")
    end
  end

  # Checkbox, switch and select triggers are `<button>`s carrying an ARIA role,
  # and `role="combobox"` in particular may not take its name from its content.
  # The builder points them at the field's label; axe found this missing once, so
  # the link has to keep resolving to an element that exists.
  describe "labelling the button-based controls" do
    def name_of(doc, slot)
      doc.at_css("##{doc.at_css("[data-slot=#{slot}]")['aria-labelledby']}")&.text
    end

    it "points the switch at the label the field rendered" do
      doc = render_form(valid, "<%= f.shadcn_switch_field :newsletter, label: 'Newsletter' %>")

      expect(name_of(doc, "switch")).to eq("Newsletter")
    end

    it "points the checkbox at the label the field rendered" do
      doc = render_form(valid, "<%= f.shadcn_checkbox_field :newsletter, label: 'Newsletter' %>")

      expect(name_of(doc, "checkbox")).to eq("Newsletter")
    end
  end

  describe "#shadcn_radio_group" do
    subject(:items) { doc.css("[data-slot=radio-group-item]") }

    let(:doc) do
      render_form(valid, "<%= f.shadcn_radio_group :plan, [['Free', 'free'], ['Pro', 'pro']] %>")
    end

    it "renders each option once, in order" do
      expect(items.map { |item| item["data-value"] }).to eq(%w[free pro])
    end

    it "checks the one the model holds" do
      expect(items.map { |item| item["data-state"] }).to eq(%w[unchecked checked])
    end

    it "wires each option to its own label" do
      expect(doc.css("[data-slot=label]").map { |label| label["for"] })
        .to eq(items.map { |item| item["id"] })
    end
  end

  describe "#shadcn_submit" do
    it "renders a submit button", :aggregate_failures do
      doc = render_form(valid, "<%= f.shadcn_submit 'Save' %>")

      expect(doc.at_css("[data-slot=button]")["type"]).to eq("submit")
      expect(doc.at_css("[data-slot=button]").text.strip).to eq("Save")
    end
  end

  describe "shadcn_form_with" do
    it "is a normal Rails form", :aggregate_failures do
      doc = render_form(valid, "<%= f.shadcn_input :email %>")

      expect(doc.at_css("form")["action"]).to eq("/x")
      expect(doc.at_css("form")["method"]).to eq("post")
    end
  end
end
