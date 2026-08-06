# frozen_string_literal: true

require "spec_helper"

# The base class is where the React → ViewComponent mapping lives, so these
# examples pin the mapping itself rather than any one component.
RSpec.describe Shadcn::ApplicationViewComponent do
  describe "data-slot" do
    it "stamps the slot name shadcn uses" do
      render_inline(Shadcn::Card::Component.new)

      expect(root["data-slot"]).to eq("card")
    end

    it "is inherited by specialisations", :aggregate_failures do
      expect(Shadcn::Sheet::Trigger::Component.slot_name).to eq("sheet-trigger")
      expect(Shadcn::Pagination::Previous::Component.slot_name).to eq("pagination-link")
    end
  end

  describe "attribute forwarding" do
    it "splats arbitrary attributes onto the element, like {...props}", :aggregate_failures do
      render_inline(Shadcn::Card::Component.new(id: "x", role: "region", data: { testid: "t" }))

      expect(root["id"]).to eq("x")
      expect(root["role"]).to eq("region")
      expect(root["data-testid"]).to eq("t")
    end

    it "merges data hashes with the component's own data attributes", :aggregate_failures do
      render_inline(Shadcn::Button::Component.new(data: { testid: "t" }))

      expect(root["data-slot"]).to eq("button")
      expect(root["data-variant"]).to eq("default")
      expect(root["data-testid"]).to eq("t")
    end

    # React spreads `{...props}` last, so anything the caller passes beats what
    # the component computed. Getting this backwards silently ignored every
    # attribute a caller tried to override.
    context "when the caller passes an attribute the component also sets" do
      it "keeps the caller's value" do
        render_inline(Shadcn::Icon::Component.new("x", width: "16"))

        expect(root["width"]).to eq("16")
      end

      it "keeps it even when a variant computed the value" do
        render_inline(Shadcn::Button::Component.new(variant: :outline, "data-variant": "custom"))

        expect(root["data-variant"]).to eq("custom")
      end
    end
  end

  # Stimulus reads a space-separated list, so a caller's action has to add to the
  # component's own rather than replace it. Both spellings have to land in one
  # attribute.
  describe "data-action" do
    context "with the attribute spelling" do
      it "concatenates onto the component's own action" do
        render_inline(Shadcn::Dialog::Close::Component.new("data-action": "click->foo#bar"))

        expect(root["data-action"]).to eq("shadcn--dialog#close click->foo#bar")
      end
    end

    context "with the idiomatic data: hash" do
      before do
        render_inline(
          Shadcn::Dialog::Close::Component.new(data: { action: "click->foo#bar", testid: "t" })
        )
      end

      it "concatenates onto the component's own action" do
        expect(root["data-action"]).to eq("shadcn--dialog#close click->foo#bar")
      end

      # Emitting it twice is invalid HTML, and the browser keeps the first — so
      # the component's own action would never fire.
      it "emits the attribute exactly once" do
        expect(rendered_content.scan("data-action=").size).to eq(1)
      end

      it "keeps the rest of the data hash" do
        expect(root["data-testid"]).to eq("t")
      end
    end
  end

  describe "as: (shadcn's asChild)" do
    it "swaps the rendered element while keeping slot and classes", :aggregate_failures do
      render_inline(Shadcn::Badge::Component.new(as: :a, href: "/x")) { "New" }

      expect(root.name).to eq("a")
      expect(root["href"]).to eq("/x")
      expect(root["data-slot"]).to eq("badge")
      expect(root_classes).to include("rounded-full")
    end
  end

  describe "class memoisation" do
    before { ShadcnViewComponent.reset! }

    it "returns the same classes cached as uncached" do
      render_inline(Shadcn::Button::Component.new(variant: :outline))
      cold = root["class"]

      render_inline(Shadcn::Button::Component.new(variant: :outline))

      expect(root["class"]).to eq(cold)
    end

    it "keys on the variants, not just the class" do
      render_inline(Shadcn::Button::Component.new(variant: :outline))
      outline = root["class"]

      render_inline(Shadcn::Button::Component.new(variant: :ghost))

      expect(root["class"]).not_to eq(outline)
    end

    context "when the caller supplies classes" do
      it "does not cache them onto the next render" do
        render_inline(Shadcn::Button::Component.new(class: "h-20"))
        expect(root_classes).to include("h-20")

        render_inline(Shadcn::Button::Component.new)

        expect(root_classes).not_to include("h-20")
      end
    end
  end

  context "when a part declares no classes of its own" do
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

# `cn` is a module function rather than a method on the base class, but it is
# what `css_classes` calls, and this is the only place it is exercised directly.
RSpec.describe ShadcnViewComponent do
  describe ".cn" do
    it "lets the later class win a conflict, like shadcn's cn()" do
      expect(described_class.cn("px-2 py-1", "px-4")).to eq("py-1 px-4")
    end

    it "keeps non-conflicting classes" do
      expect(described_class.cn("flex items-center", "gap-2")).to eq("flex items-center gap-2")
    end

    it "drops nils and falses, and takes hashes conditionally" do
      expect(described_class.cn("flex", nil, false, { "hidden" => false, "gap-2" => true }))
        .to eq("flex gap-2")
    end
  end
end
