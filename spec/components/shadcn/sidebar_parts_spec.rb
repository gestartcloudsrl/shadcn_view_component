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

  # The one part in the family that carries no `data-sidebar` at all, so it is
  # declared with the plain macro and must not gain one.
  it "leaves the inset alone, which upstream stamps only with data-slot" do
    render_inline(Shadcn::Sidebar::Inset::Component.new)

    element = page.find("[data-slot='sidebar-inset']")
    expect(element.tag_name).to eq("main")
    expect(element["data-sidebar"]).to be_nil
  end
end
