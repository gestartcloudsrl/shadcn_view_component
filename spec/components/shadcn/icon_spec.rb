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

  # An alias is a second spelling of one icon, so a host registering either
  # must reach both — and for as long as the aliases existed, neither reached
  # anything: the component resolved the alias in its constructor, so
  # `register("more-horizontal", …)` was stored under a key nothing looked up
  # and the bundled drawing kept rendering. The gem's own pagination and
  # breadcrumb render `"more-horizontal"`, and the spinner renders `"loader-2"`.
  describe ".register, under an alias" do
    ShadcnViewComponent::IconRegistry::ALIASES.each do |from, to|
      context "when a host registers #{from}" do
        before { Shadcn::Icon.register(from, %(<path d="M1 1h2"/>)) }

        after { Shadcn::Icon.registered.delete(to) }

        it "renders under the name it registered" do
          render_inline(described_class.new(from))

          expect(page).to have_css(%(path[d="M1 1h2"]), visible: :all)
        end

        it "renders under #{to}, which is the same icon" do
          render_inline(described_class.new(to))

          expect(page).to have_css(%(path[d="M1 1h2"]), visible: :all)
        end
      end

      context "when a host registers #{to}" do
        before { Shadcn::Icon.register(to, %(<path d="M3 3h2"/>)) }

        after { Shadcn::Icon.registered.delete(to) }

        it "renders under #{from} too" do
          render_inline(described_class.new(from))

          expect(page).to have_css(%(path[d="M3 3h2"]), visible: :all)
        end
      end
    end

    # One entry per icon, not one per spelling: two keys would let a host
    # register both and leave which one wins to the order they are read in.
    it "keeps one entry however it was spelled", :aggregate_failures do
      Shadcn::Icon.register("more-horizontal", %(<path d="M1 1h2"/>))
      Shadcn::Icon.register("ellipsis", %(<path d="M3 3h2"/>))

      expect(Shadcn::Icon.registered.keys).to include("ellipsis")
      expect(Shadcn::Icon.registered.keys).not_to include("more-horizontal")
      expect(Shadcn::Icon.registered["ellipsis"]).to eq(%(<path d="M3 3h2"/>))
    ensure
      Shadcn::Icon.registered.delete("ellipsis")
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
