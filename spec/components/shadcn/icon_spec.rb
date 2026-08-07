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
