# frozen_string_literal: true

require "spec_helper"

# The base class is where the React → ViewComponent mapping lives, so these
# examples pin the mapping itself rather than any one component.
RSpec.describe Shadcn::ApplicationViewComponent do
  describe "cn (tailwind-merge)" do
    it "lets the later class win a conflict, like shadcn's cn()" do
      expect(ShadcnViewComponent.cn("px-2 py-1", "px-4")).to eq("py-1 px-4")
    end

    it "keeps non-conflicting classes" do
      expect(ShadcnViewComponent.cn("flex items-center", "gap-2")).to eq("flex items-center gap-2")
    end

    it "drops nils and falses, and takes hashes conditionally" do
      expect(ShadcnViewComponent.cn("flex", nil, false, { "hidden" => false, "gap-2" => true }))
        .to eq("flex gap-2")
    end
  end

  describe "data-slot" do
    it "stamps the slot name shadcn uses" do
      render_inline(Shadcn::Card::Component.new)
      expect(root["data-slot"]).to eq("card")
    end

    it "is inherited by specialisations" do
      expect(Shadcn::Sheet::Trigger::Component.slot_name).to eq("sheet-trigger")
      expect(Shadcn::Pagination::Previous::Component.slot_name).to eq("pagination-link")
    end
  end

  describe "attribute forwarding" do
    it "splats arbitrary attributes onto the element, like {...props}" do
      render_inline(Shadcn::Card::Component.new(id: "x", role: "region", data: { testid: "t" }))

      expect(root["id"]).to eq("x")
      expect(root["role"]).to eq("region")
      expect(root["data-testid"]).to eq("t")
    end

    it "merges data hashes with the component's own data attributes" do
      render_inline(Shadcn::Button::Component.new(data: { testid: "t" }))

      expect(root["data-slot"]).to eq("button")
      expect(root["data-variant"]).to eq("default")
      expect(root["data-testid"]).to eq("t")
    end

    # React spreads `{...props}` last, so anything the caller passes beats what
    # the component computed. Getting this backwards silently ignored every
    # attribute a caller tried to override.
    it "lets the caller win over the component's own attributes" do
      render_inline(Shadcn::Icon::Component.new("x", width: "16"))
      expect(root["width"]).to eq("16")

      render_inline(Shadcn::Button::Component.new(variant: :outline, "data-variant": "custom"))
      expect(root["data-variant"]).to eq("custom")
    end
  end

  describe "data-action" do
    # Stimulus reads a space-separated list, so a caller's action has to add to
    # the component's own. Both spellings must land in one attribute: emitting
    # it twice is invalid HTML and the browser keeps only the first.
    it "concatenates rather than replacing, in both spellings" do
      render_inline(Shadcn::Dialog::Close::Component.new("data-action": "click->foo#bar"))
      expect(root["data-action"]).to eq("shadcn--dialog#close click->foo#bar")

      render_inline(Shadcn::Dialog::Close::Component.new(data: { action: "click->foo#bar" }))
      expect(root["data-action"]).to eq("shadcn--dialog#close click->foo#bar")
    end

    it "emits the attribute exactly once" do
      render_inline(Shadcn::Dialog::Close::Component.new(data: { action: "click->foo#bar" }))

      expect(rendered_content.scan("data-action=").size).to eq(1)
    end

    it "keeps the rest of the data hash" do
      render_inline(Shadcn::Dialog::Close::Component.new(data: { action: "a#b", testid: "t" }))

      expect(root["data-testid"]).to eq("t")
    end
  end

  describe "as: (shadcn's asChild)" do
    it "swaps the rendered element while keeping slot and classes" do
      render_inline(Shadcn::Badge::Component.new(as: :a, href: "/x")) { "New" }

      expect(root.name).to eq("a")
      expect(root["href"]).to eq("/x")
      expect(root["data-slot"]).to eq("badge")
      expect(root_classes).to include("rounded-full")
    end
  end

  describe "class memoisation" do
    it "returns the same classes cached as uncached" do
      ShadcnViewComponent.reset!
      render_inline(Shadcn::Button::Component.new(variant: :outline))
      cold = root["class"]

      render_inline(Shadcn::Button::Component.new(variant: :outline))

      expect(root["class"]).to eq(cold)
    end

    it "keys on the variants, not just the class" do
      ShadcnViewComponent.reset!

      render_inline(Shadcn::Button::Component.new(variant: :outline))
      outline = root["class"]
      render_inline(Shadcn::Button::Component.new(variant: :ghost))

      expect(root["class"]).not_to eq(outline)
    end

    it "does not cache when the caller supplies classes" do
      render_inline(Shadcn::Button::Component.new(class: "h-20"))
      expect(root_classes).to include("h-20")

      render_inline(Shadcn::Button::Component.new)
      expect(root_classes).not_to include("h-20")
    end
  end

  describe "parts without classes of their own" do
    it "still forwards the caller's classes" do
      render_inline(Shadcn::Pagination::Item::Component.new(class: "mx-1"))
      expect(root["class"]).to eq("mx-1")
    end

    it "emits no class attribute when there is nothing to emit" do
      render_inline(Shadcn::Pagination::Item::Component.new)
      expect(root["class"]).to be_nil
    end
  end
end
