# frozen_string_literal: true

require "spec_helper"

# The API surface every other component inherits — variants, caller props, `as:` —
# exercised on the component that has the most of it. Which classes upstream
# emits is `parity_spec`'s job; what a whole rendering looks like is
# `snapshot_spec`'s.
RSpec.describe Shadcn::Button::Component do
  context "without arguments" do
    it "renders a button carrying shadcn's slot", :aggregate_failures do
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
  end

  # One example per axis with the values in a table, rather than an example per
  # value. Each row also names the class that distinguishes it, which is what was
  # missing before: asserting that `data-variant` echoes its argument passes for
  # any string, a misspelled variant included.
  describe "variant:" do
    it "selects that variant's classes", :aggregate_failures do
      {
        default: "bg-primary",
        destructive: "bg-destructive",
        outline: "border",
        secondary: "bg-secondary",
        ghost: "hover:bg-accent",
        link: "underline-offset-4"
      }.each do |variant, signature|
        render_inline(described_class.new(variant:))

        expect(root["data-variant"]).to eq(variant.to_s)
        expect(root_classes).to include(signature), "#{variant} is missing #{signature}"
      end
    end
  end

  describe "size:" do
    it "selects that size's classes", :aggregate_failures do
      {
        default: "h-9",
        xs: "h-6",
        sm: "h-8",
        lg: "h-10",
        icon: "size-9",
        "icon-xs": "size-6",
        "icon-sm": "size-8",
        "icon-lg": "size-10"
      }.each do |size, signature|
        render_inline(described_class.new(size:))

        expect(root["data-size"]).to eq(size.to_s)
        expect(root_classes).to include(signature), "#{size} is missing #{signature}"
      end
    end
  end

  context "when the caller passes a conflicting class" do
    it "keeps the caller's and drops the component's" do
      render_inline(described_class.new(class: "h-20"))

      expect(root_classes).to include("h-20")
      expect(root_classes).not_to include("h-9")
    end
  end

  context "with arbitrary attributes" do
    it "forwards them, the way React spreads {...props}", :aggregate_failures do
      render_inline(described_class.new(type: "submit", disabled: true, data: { testid: "save" }))

      expect(root["type"]).to eq("submit")
      expect(root["disabled"]).to eq("disabled")
      expect(root["data-testid"]).to eq("save")
    end
  end

  context "with as:" do
    it "renders that element instead, the way asChild does", :aggregate_failures do
      render_inline(described_class.new(as: :a, href: "/x")) { "Link" }

      expect(root.name).to eq("a")
      expect(root["href"]).to eq("/x")
      expect(root["data-slot"]).to eq("button")
    end
  end

  # shadcn exports `buttonVariants` so other components can borrow the classes.
  # Pagination and the dialog footer both call this, and nothing covered it.
  describe ".variant_classes" do
    it "compiles what the button itself would render" do
      render_inline(described_class.new(variant: :outline, size: :sm))

      expect(described_class.variant_classes(variant: :outline, size: :sm)).to eq(root["class"])
    end

    it "lets a caller class win over the size it conflicts with", :aggregate_failures do
      classes = described_class.variant_classes(size: :sm, class: "h-20")

      expect(classes).to include("h-20")
      expect(classes).not_to include("h-8")
    end
  end
end
