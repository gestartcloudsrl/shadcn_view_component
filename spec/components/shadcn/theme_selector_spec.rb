# frozen_string_literal: true

require "spec_helper"

RSpec.describe Shadcn::ThemeSelector::Component, type: :component do
  it "does not reuse an id between two instances on a page" do
    first = render_inline(described_class.new).to_html
    second = render_inline(described_class.new).to_html

    ids = [ first, second ].map { |html| html[/id="(shadcn-theme-selector-[0-9a-f]{8})"/, 1] }

    expect(ids).to all(be_present)
    expect(ids.uniq.size).to eq(2)
  end

  it "names the trigger with aria-labelledby, as the FormBuilder does" do
    render_inline(described_class.new)

    label = page.find("[data-slot=label]")
    expect(page).to have_css("[data-slot=select-trigger][aria-labelledby='#{label[:id]}']")
  end
end
