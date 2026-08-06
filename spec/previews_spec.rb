# frozen_string_literal: true

require "spec_helper"

# Renders every Lookbook example template. It is a cheap smoke test over the
# whole library: a renamed slot, a missing part or a bad template shows up here
# rather than in the browser.
RSpec.describe "component previews" do
  COMPONENTS = Pathname(__dir__).join("../app/components/shadcn")
  TEMPLATES = Dir[COMPONENTS.join("*/previews/*.html.erb")].sort

  it "has a preview for every component family" do
    families = TEMPLATES.map { |path| Pathname(path).parent.parent.basename.to_s }.uniq
    expect(families.size).to be >= 30
  end

  TEMPLATES.each do |template|
    name = Pathname(template).relative_path_from(COMPONENTS).to_s

    it "renders #{name}" do
      rendered = ApplicationController.renderer.render(inline: File.read(template))

      expect(rendered).to be_present
    end
  end
end
