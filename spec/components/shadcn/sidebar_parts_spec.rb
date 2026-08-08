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

  # The one part in the family that carries no `data-sidebar` at all, so it is
  # declared with the plain macro and must not gain one.
  it "leaves the inset alone, which upstream stamps only with data-slot" do
    render_inline(Shadcn::Sidebar::Inset::Component.new)

    element = page.find("[data-slot='sidebar-inset']")
    expect(element.tag_name).to eq("main")
    expect(element["data-sidebar"]).to be_nil
  end
end
