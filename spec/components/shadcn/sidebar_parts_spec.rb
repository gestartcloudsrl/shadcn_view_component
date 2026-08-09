# frozen_string_literal: true

require "spec_helper"

# shadcn stamps a second attribute on every part of this family:
# `data-sidebar="header"` beside `data-slot="sidebar-header"`, and so on for all
# 24. The `part` macro deliberately declares a slot, classes and a tag and
# nothing else, so taken literally this family would need 23 files of eleven
# lines each — recreating exactly what `part` was written to remove.
#
# `sidebar_part` adds the one attribute, derived rather than configured:
# measured across the vendored source, `data-sidebar` is `data-slot` without its
# `sidebar-` prefix in 21 of 21 cases, with no exceptions. That is a rule, not a
# parameter, which is why this does not widen `part` itself.
RSpec.describe Shadcn::Sidebar, type: :component do
  it "stamps data-sidebar beside data-slot, derived from it" do
    render_inline(Shadcn::Sidebar::Header::Component.new) { "Logo" }

    element = page.find("[data-slot='sidebar-header']")
    expect(element["data-sidebar"]).to eq("header")
    expect(element).to have_text("Logo")
  end

  it "lets a caller override the derived value like any other attribute" do
    render_inline(Shadcn::Sidebar::Footer::Component.new("data-sidebar": "custom"))

    expect(page.find("[data-slot='sidebar-footer']")["data-sidebar"]).to eq("custom")
  end

  # The nine declared with `sidebar_part`, each checked for the two attributes
  # and the element upstream uses. The class strings were extracted from the
  # vendored source rather than transcribed, and every token verified to exist
  # in its own block — transcription had already gone wrong twice before that.
  {
    "sidebar-group" => %w[group div],
    "sidebar-group-label" => %w[group-label div],
    "sidebar-group-action" => %w[group-action button],
    "sidebar-group-content" => %w[group-content div],
    "sidebar-menu" => %w[menu ul],
    "sidebar-menu-item" => %w[menu-item li],
    "sidebar-menu-badge" => %w[menu-badge div],
    "sidebar-menu-sub" => %w[menu-sub ul],
    "sidebar-menu-sub-item" => %w[menu-sub-item li]
  }.each do |slot, (marker, tag)|
    it "renders #{slot} as a #{tag} carrying data-sidebar=#{marker}" do
      component = slot.delete_prefix("sidebar-").tr("-", "_").camelize
      render_inline(described_class.const_get(component)::Component.new)

      element = page.find("[data-slot='#{slot}']", visible: :all)
      expect(element["data-sidebar"]).to eq(marker)
      expect(element.tag_name).to eq(tag)
    end
  end

  describe "the panel" do
    it "renders the desktop tree, with data-collapsible empty and the value kept beside it" do
      render_inline(described_class::Component.new) { "nav" }

      panel = page.find("[data-slot='sidebar']")
      expect(panel["data-collapsible"]).to eq("")
      expect(panel["data-sidebar-collapsible"]).to eq("offcanvas")
      expect(panel["data-side"]).to eq("left")
      expect(page).to have_css("[data-slot='sidebar-gap']")
      expect(page.find("[data-slot='sidebar-inner']")).to have_text("nav")
    end

    # A different element with different classes, not the same one with a flag
    # (vendor/shadcn/ui/sidebar.tsx:166-180).
    it "renders a bare panel when collapsible is none" do
      render_inline(described_class::Component.new(collapsible: :none)) { "nav" }

      expect(page).to have_no_css("[data-slot='sidebar-gap']")
      expect(page.find("[data-slot='sidebar']")["data-side"]).to be_nil
      expect(page.find("[data-slot='sidebar']")[:class]).to include("w-(--sidebar-width)")
    end

    it "moves the container to the right and pads it for the inset variant" do
      render_inline(described_class::Component.new(side: :right, variant: :inset))

      container = page.find("[data-slot='sidebar-container']")[:class]
      expect(container).to include("right-0")
      expect(container).to include("p-2")
    end
  end

  describe "the trigger and the rail" do
    it "gives the trigger the button's ghost icon styling and a screen-reader name" do
      render_inline(described_class::Trigger::Component.new)

      trigger = page.find("[data-slot='sidebar-trigger']")
      expect(trigger["data-sidebar"]).to eq("trigger")
      expect(trigger[:class]).to include("size-7")
      expect(page.find("span.sr-only")).to have_text("Toggle Sidebar")
    end

    # Upstream keeps the rail out of the tab order because it duplicates the
    # trigger (sidebar.tsx:289).
    it "keeps the rail out of the tab order" do
      render_inline(described_class::Rail::Component.new)

      rail = page.find("[data-slot='sidebar-rail']", visible: :all)
      expect(rail["tabindex"]).to eq("-1")
      expect(rail["aria-label"]).to eq("Toggle Sidebar")
    end
  end

  describe "the parts that carry a variant or wrap another component" do
    it "restamps the ported Input and keeps its classes" do
      render_inline(described_class::Input::Component.new)

      field = page.find("[data-slot='sidebar-input']")
      expect(field["data-sidebar"]).to eq("input")
      expect(field[:class]).to include("h-8")
      # The parent's own classes are inherited rather than restated.
      expect(field[:class]).to include("border-input")
    end

    it "gives the menu button its size and active attributes" do
      render_inline(described_class::MenuButton::Component.new(size: :lg, active: true))

      button = page.find("[data-slot='sidebar-menu-button']")
      expect(button["data-size"]).to eq("lg")
      expect(button["data-active"]).to eq("true")
      expect(button[:class]).to include("h-12")
    end

    # Upstream wraps the button in a Tooltip and decides visibility with a
    # runtime prop (sidebar.tsx:534-542). Here the two conditions are CSS on the
    # panel's own group, so the element still has to come out as a
    # sidebar-menu-button rather than a tooltip-trigger.
    it "wraps the button in a tooltip without losing its own slot" do
      render_inline(described_class::MenuButton::Component.new(tooltip: "Playground")) { "Playground" }

      button = page.find("[data-slot='sidebar-menu-button']")
      expect(button["data-sidebar"]).to eq("menu-button")
      expect(button["data-shadcn--tooltip-target"]).to eq("trigger")

      label = page.find("[data-slot='tooltip-content']", visible: :all)
      expect(label).to have_text("Playground")
      expect(label[:class]).to include("group-data-[state=expanded]:hidden")
      expect(label[:class]).to include("group-data-[mobile=true]:hidden")
    end

    it "renders no tooltip when none is asked for" do
      render_inline(described_class::MenuButton::Component.new) { "Playground" }

      expect(page).to have_no_css("[data-slot='tooltip-content']", visible: :all)
      expect(page.find("[data-slot='sidebar-menu-button']")["data-shadcn--tooltip-target"]).to be_nil
    end

    it "adds the hover-reveal classes to a menu action only when asked" do
      render_inline(described_class::MenuAction::Component.new)
      expect(page.find("[data-slot='sidebar-menu-action']")[:class]).not_to include("md:opacity-0")

      render_inline(described_class::MenuAction::Component.new(show_on_hover: true))
      expect(page.find("[data-slot='sidebar-menu-action']")[:class]).to include("md:opacity-0")
    end

    it "renders the sub button as a link, sized md by default" do
      render_inline(described_class::MenuSubButton::Component.new)

      link = page.find("[data-slot='sidebar-menu-sub-button']")
      expect(link.tag_name).to eq("a")
      expect(link["data-size"]).to eq("md")
      expect(link[:class]).to include("text-sm")
    end

    # Upstream randomises the width so a column of them does not look like a
    # barcode (sidebar.tsx:611-613).
    it "draws a skeleton width inside upstream's range, and the icon only on request" do
      render_inline(described_class::MenuSkeleton::Component.new)
      expect(page).to have_no_css("[data-sidebar='menu-skeleton-icon']")

      width = page.find("[data-sidebar='menu-skeleton-text']")[:style][/--skeleton-width:\s*(\d+)%/, 1].to_i
      expect(width).to be_between(50, 90)

      render_inline(described_class::MenuSkeleton::Component.new(show_icon: true))
      expect(page).to have_css("[data-sidebar='menu-skeleton-icon']")
    end
  end

  # The one part in the family that carries no `data-sidebar` at all, so it is
  # declared with the plain macro and must not gain one.
  it "leaves the inset alone, which upstream stamps only with data-slot" do
    render_inline(Shadcn::Sidebar::Inset::Component.new)

    element = page.find("[data-slot='sidebar-inset']")
    expect(element.tag_name).to eq("main")
    expect(element["data-sidebar"]).to be_nil
  end
end
