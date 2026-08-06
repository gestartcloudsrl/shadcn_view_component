# frozen_string_literal: true

require "spec_helper"

RSpec.describe Shadcn::Button::Component do
  it "renders a button carrying the shadcn data attributes" do
    render_inline(described_class.new) { "Click" }

    expect(root.name).to eq("button")
    expect(root["data-slot"]).to eq("button")
    expect(root["data-variant"]).to eq("default")
    expect(root["data-size"]).to eq("default")
    expect(root.text).to eq("Click")
  end

  it "applies the default variant and size classes" do
    render_inline(described_class.new)

    expect_classes("bg-primary", "text-primary-foreground", "hover:bg-primary/90")
    expect_classes("h-9", "px-4", "py-2", "has-[>svg]:px-3")
  end

  %i[default destructive outline secondary ghost link].each do |variant|
    it "supports the #{variant} variant" do
      render_inline(described_class.new(variant:))
      expect(root["data-variant"]).to eq(variant.to_s)
    end
  end

  [ :default, :xs, :sm, :lg, :icon, :"icon-xs", :"icon-sm", :"icon-lg" ].each do |size|
    it "supports the #{size} size" do
      render_inline(described_class.new(size:))
      expect(root["data-size"]).to eq(size.to_s)
    end
  end

  it "lets caller classes win over conflicting component classes" do
    render_inline(described_class.new(class: "h-20"))

    expect(root_classes).to include("h-20")
    expect(root_classes).not_to include("h-9")
  end

  it "forwards arbitrary attributes like React's {...props}" do
    render_inline(described_class.new(type: "submit", disabled: true, data: { testid: "save" }))

    expect(root["type"]).to eq("submit")
    expect(root["disabled"]).to eq("disabled")
    expect(root["data-testid"]).to eq("save")
  end

  it "renders a different element with as: (shadcn's asChild)" do
    render_inline(described_class.new(as: :a, href: "/x")) { "Link" }

    expect(root.name).to eq("a")
    expect(root["href"]).to eq("/x")
    expect(root["data-slot"]).to eq("button")
  end
end
