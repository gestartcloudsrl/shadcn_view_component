# frozen_string_literal: true

require "spec_helper"

RSpec.describe Shadcn::Icon::Component, type: :component do
  describe ".register" do
    before { Shadcn::Icon.register("star", %(<path d="M12 2 15 9l7 .5-5 4 1 7-6-3z"/>)) }

    after { Shadcn::Icon.registered.delete("star") }

    it "renders a registered icon like a bundled one" do
      render_inline(described_class.new("star"))

      expect(page).to have_css("svg.lucide.lucide-star path")
    end
  end

  describe ".register, over a bundled name" do
    before { Shadcn::Icon.register("check", %(<path d="M4 4h16"/>)) }

    after { Shadcn::Icon.registered.delete("check") }

    it "replaces the bundled drawing rather than being ignored" do
      render_inline(described_class.new("check"))

      expect(page).to have_css('svg.lucide-check path[d="M4 4h16"]')
    end
  end

  describe "the bundled set" do
    # The searchable select's addon renders this one. An icon that is not
    # bundled raises rather than rendering a gap, so a missing entry here does
    # not degrade — it takes the whole page down in development.
    it "includes the magnifier the searchable select needs" do
      render_inline(described_class.new("search"))

      expect(page).to have_css('svg.lucide-search path[d="m21 21-4.3-4.3"]')
    end
  end

  context "with an unknown name" do
    it "raises, so a typo is loud where it can be fixed" do
      expect { described_class.new("nope") }.to raise_error(ArgumentError)
    end

    it "renders nothing when the environment is not local" do
      allow(Rails.env).to receive(:local?).and_return(false)

      expect(render_inline(described_class.new("nope")).to_html).to be_blank
    end
  end
end
