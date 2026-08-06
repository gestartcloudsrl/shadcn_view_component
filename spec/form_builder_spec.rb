# frozen_string_literal: true

require "spec_helper"

RSpec.describe ShadcnViewComponent::FormBuilder do
  # A plain ActiveModel, so the specs exercise the same path a real record does
  # without needing a database.
  model_class = Class.new do
    include ActiveModel::Model
    include ActiveModel::Attributes

    def self.name = "Signup"

    attribute :email, :string
    attribute :bio, :string
    attribute :plan, :string
    attribute :newsletter, :boolean

    validates :email, presence: true, format: { with: /@/, message: "must contain @" }
  end

  def render_form(model, template)
    html = ApplicationController.renderer.render(
      inline: "<%= shadcn_form_with(model: model, url: '/x', scope: :signup) do |f| %>#{template}<% end %>",
      locals: { model: }
    )
    Nokogiri::HTML5.fragment(html)
  end

  let(:valid) { model_class.new(email: "a@b.com", plan: "pro", newsletter: true).tap(&:valid?) }
  let(:invalid) { model_class.new(plan: "pro").tap(&:valid?) }

  describe "#shadcn_field" do
    subject(:doc) do
      render_form(invalid, "<%= f.shadcn_input_field :email, label: 'Email', description: 'Never shared.' %>")
    end

    it "wires the label to the control" do
      expect(doc.at_css("[data-slot=field-label]")["for"]).to eq("signup_email")
      expect(doc.at_css("[data-slot=input]")["id"]).to eq("signup_email")
    end

    it "names the control for the form" do
      expect(doc.at_css("[data-slot=input]")["name"]).to eq("signup[email]")
    end

    it "marks the field and the control invalid from the model" do
      expect(doc.at_css("[data-slot=field]")["data-invalid"]).to eq("true")
      expect(doc.at_css("[data-slot=input]")["aria-invalid"]).to eq("true")
    end

    it "renders every validation message" do
      messages = doc.at_css("[data-slot=field-error]").css("li").map(&:text)

      expect(messages).to eq([ "can't be blank", "must contain @" ])
    end

    it "points aria-describedby at both the description and the error" do
      expect(doc.at_css("[data-slot=input]")["aria-describedby"])
        .to eq("signup_email_description signup_email_error")
      expect(doc.at_css("[data-slot=field-description]")["id"]).to eq("signup_email_description")
      expect(doc.at_css("[data-slot=field-error]")["id"]).to eq("signup_email_error")
    end

    it "leaves a valid field unmarked and without an error" do
      doc = render_form(valid, "<%= f.shadcn_input_field :email, label: 'Email' %>")

      expect(doc.at_css("[data-slot=field]")["data-invalid"]).to be_nil
      expect(doc.at_css("[data-slot=input]")["aria-invalid"]).to be_nil
      expect(doc.at_css("[data-slot=field-error]")).to be_nil
    end

    it "omits the label when none is given" do
      doc = render_form(valid, "<%= f.shadcn_input_field :email %>")

      expect(doc.at_css("[data-slot=field-label]")).to be_nil
    end
  end

  describe "controls" do
    it "fills the input from the model" do
      doc = render_form(valid, "<%= f.shadcn_input :email %>")

      expect(doc.at_css("[data-slot=input]")["value"]).to eq("a@b.com")
    end

    it "puts the textarea's value in its body, not an attribute" do
      model = model_class.new(bio: "hello").tap(&:valid?)
      doc = render_form(model, "<%= f.shadcn_textarea :bio %>")

      expect(doc.at_css("[data-slot=textarea]").text).to eq("hello")
    end

    it "selects the current option in a native select" do
      doc = render_form(valid, "<%= f.shadcn_native_select :plan, [['Free', 'free'], ['Pro', 'pro']] %>")
      states = doc.css("[data-slot=native-select-option]").to_h { |o| [ o["value"], o["selected"] ] }

      expect(states).to eq("free" => nil, "pro" => "selected")
    end

    it "mirrors the styled select into a hidden input and labels its trigger" do
      doc = render_form(valid, "<%= f.shadcn_select :plan, [['Free', 'free'], ['Pro', 'pro']] %>")

      expect(doc.at_css("input[name='signup[plan]']")["value"]).to eq("pro")
      expect(doc.at_css("[data-slot=select-value]").text.strip).to eq("Pro")
      expect(doc.at_css("[data-value=pro]")["data-state"]).to eq("checked")
    end

    it "checks the switch from a boolean attribute" do
      doc = render_form(valid, "<%= f.shadcn_switch :newsletter %>")

      expect(doc.at_css("[data-slot=switch]")["data-state"]).to eq("checked")
      expect(doc.at_css("input[type=checkbox]")["name"]).to eq("signup[newsletter]")
    end

    it "renders each radio option once, wired to its own label" do
      doc = render_form(valid, "<%= f.shadcn_radio_group :plan, [['Free', 'free'], ['Pro', 'pro']] %>")
      items = doc.css("[data-slot=radio-group-item]")

      expect(items.map { |item| item["data-value"] }).to eq(%w[free pro])
      expect(items.map { |item| item["data-state"] }).to eq(%w[unchecked checked])
      expect(doc.css("[data-slot=label]").map { |label| label["for"] })
        .to eq(items.map { |item| item["id"] })
    end

    it "renders a submit button" do
      doc = render_form(valid, "<%= f.shadcn_submit 'Save' %>")

      expect(doc.at_css("[data-slot=button]")["type"]).to eq("submit")
      expect(doc.at_css("[data-slot=button]").text.strip).to eq("Save")
    end
  end

  describe "the form itself" do
    it "is a normal Rails form" do
      doc = render_form(valid, "<%= f.shadcn_input :email %>")

      expect(doc.at_css("form")["action"]).to eq("/x")
      expect(doc.at_css("form")["method"]).to eq("post")
    end
  end
end
